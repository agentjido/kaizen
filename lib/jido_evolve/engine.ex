defmodule Jido.Evolve.Engine do
  @moduledoc """
  Core evolutionary algorithm engine.

  Provides a stream-based interface for running evolutionary algorithms
  with pluggable strategies for fitness, mutation, selection, and crossover.
  """

  require Logger

  alias Jido.Evolve.{Config, Error, State}

  @runtime_opts_schema Zoi.keyword(
                         [
                           mutation: Zoi.atom() |> Zoi.refine({__MODULE__, :validate_mutation_module, []}),
                           selection: Zoi.atom() |> Zoi.refine({__MODULE__, :validate_selection_module, []}),
                           crossover: Zoi.atom() |> Zoi.refine({__MODULE__, :validate_crossover_module, []}),
                           context: Zoi.map() |> Zoi.default(%{})
                         ],
                         coerce: true
                       )

  @doc """
  Run an evolutionary algorithm with the given configuration.

  Returns a stream of `Jido.Evolve.State` structs representing each generation.
  The stream is lazy, so generations are only computed when consumed.

  ## Options

  - `:mutation` - Module implementing `Jido.Evolve.Mutation` (default from config)
  - `:selection` - Module implementing `Jido.Evolve.Selection` (default from config)
  - `:crossover` - Module implementing `Jido.Evolve.Crossover` (default from config)
  - `:context` - Context map passed to fitness evaluation
  """
  @spec evolve(list(any()), Config.t(), module()) :: Enumerable.t()
  def evolve(initial_population, %Config{} = config, fitness_module) do
    evolve(initial_population, config, fitness_module, [])
  end

  @spec evolve(list(any()), Config.t(), module(), keyword()) :: Enumerable.t()
  def evolve(initial_population, %Config{} = config, fitness_module, opts) when is_list(opts) do
    with {:ok, parsed_opts} <- parse_runtime_opts(opts),
         {:ok, mutation_module} <-
           resolve_strategy(Keyword.get(parsed_opts, :mutation, config.mutation_strategy), :mutation),
         {:ok, selection_module} <-
           resolve_strategy(Keyword.get(parsed_opts, :selection, config.selection_strategy), :selection),
         {:ok, crossover_module} <-
           resolve_strategy(Keyword.get(parsed_opts, :crossover, config.crossover_strategy), :crossover) do
      context = Keyword.get(parsed_opts, :context, %{})

      Config.init_random_seed(config)

      initial_state =
        initial_population
        |> State.new(config)
        |> evaluate_population(fitness_module, context)
        |> State.calculate_diversity()

      maybe_emit(config, [:jido_evolve, :evolution, :start], %{population_size: length(initial_population)}, %{
        config: config
      })

      Stream.unfold(initial_state, fn state ->
        if State.terminated?(state) or state.generation >= config.generations do
          maybe_emit(config, [:jido_evolve, :evolution, :stop], %{generation: state.generation}, %{state: state})
          nil
        else
          next_state =
            evolution_step(
              state,
              fitness_module,
              mutation_module,
              selection_module,
              crossover_module,
              context
            )

          {state, next_state}
        end
      end)
    else
      {:error, error} -> raise error
    end
  end

  @doc false
  @spec evolve(list(any()), Config.t(), module(), any()) :: Enumerable.t()
  def evolve(_initial_population, %Config{}, _fitness_module, _opts) do
    raise Error.validation_error("engine options must be a keyword list", %{field: :opts})
  end

  @doc """
  Perform a single evolution step.
  """
  @spec evolution_step(State.t(), module(), module(), module(), module(), map()) :: State.t()
  def evolution_step(
        state,
        fitness_module,
        mutation_module,
        selection_module,
        crossover_module,
        context
      ) do
    generation = state.generation + 1

    Logger.debug("Starting generation #{generation}",
      generation: generation,
      population_size: length(state.population),
      best_score: state.best_score
    )

    maybe_emit(state.config, [:jido_evolve, :generation, :start], %{generation: generation}, %{})

    new_state =
      state
      |> select_and_breed(selection_module, mutation_module, crossover_module)
      |> apply_elitism(state)
      |> then(&State.next_generation(&1, &1.population))
      |> evaluate_population(fitness_module, context)
      |> State.calculate_diversity()

    Logger.debug("Completed generation #{generation}",
      generation: generation,
      best_score: new_state.best_score,
      diversity: new_state.diversity
    )

    maybe_emit(
      state.config,
      [:jido_evolve, :generation, :stop],
      %{generation: generation, best_score: new_state.best_score},
      %{state: new_state}
    )

    new_state
  end

  defp evaluate_population(%State{population: population, config: config} = state, fitness_module, context) do
    Logger.debug("Evaluating population", population_size: length(population))

    maybe_emit(config, [:jido_evolve, :evaluation, :start], %{population_size: length(population)}, %{})

    scores =
      population
      |> Task.async_stream(
        fn entity ->
          case fitness_module.evaluate(entity, context) do
            {:ok, score} when is_number(score) ->
              {entity, score}

            {:ok, %{score: score}} when is_number(score) ->
              {entity, score}

            {:error, reason} ->
              log_warning(Error.execution_error("fitness evaluation failed", %{error: reason}))
              {entity, 0.0}

            other ->
              log_warning(Error.execution_error("fitness evaluation returned invalid value", %{value: other}))
              {entity, 0.0}
          end
        end,
        max_concurrency: config.max_concurrency,
        timeout: config.evaluation_timeout,
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {entity, score}}, acc ->
          Map.put(acc, entity, score)

        {:exit, reason}, acc ->
          log_warning(Error.execution_error("fitness evaluation timed out", %{reason: reason}))
          acc
      end)

    Logger.debug("Population evaluated", evaluated_count: map_size(scores))

    maybe_emit(config, [:jido_evolve, :evaluation, :stop], %{evaluated_count: map_size(scores)}, %{})

    State.update_scores(state, scores)
  end

  defp select_and_breed(
         %State{population: population, scores: scores, config: config} = state,
         selection_module,
         mutation_module,
         crossover_module
       ) do
    elite_count = Config.elite_count(config)
    offspring_count = config.population_size - elite_count

    Logger.debug("Selecting and breeding", offspring_count: offspring_count, elite_count: elite_count)

    selection_opts = [
      tournament_size: config.tournament_size,
      pressure: config.selection_pressure
    ]

    all_parents = selection_module.select(population, scores, offspring_count * 2, selection_opts)

    offspring =
      all_parents
      |> Enum.chunk_every(2)
      |> Enum.flat_map(fn
        [parent1, parent2] ->
          {child1, child2} =
            if :rand.uniform() < config.crossover_rate do
              crossover_module.crossover(parent1, parent2, config)
            else
              {parent1, parent2}
            end

          [child1, child2]
          |> Enum.map(&maybe_mutate(&1, mutation_module, config, state))

        [single_parent] ->
          [maybe_mutate(single_parent, mutation_module, config, state)]
      end)
      |> Enum.take(offspring_count)

    Logger.debug("Breeding complete", offspring_count: length(offspring))

    %{state | population: offspring}
  end

  defp maybe_mutate(child, mutation_module, config, state) do
    mutation_opts = [
      rate: config.mutation_rate,
      strength: mutation_strength(mutation_module, state.generation),
      best_fitness: state.best_score || 0.0
    ]

    case mutation_module.mutate(child, mutation_opts) do
      {:ok, mutated} ->
        mutated

      {:error, reason} ->
        log_warning(Error.execution_error("mutation failed", %{error: reason}))
        child

      other ->
        log_warning(Error.execution_error("mutation returned invalid value", %{value: other}))
        child
    end
  end

  defp mutation_strength(module, generation) do
    if function_exported?(module, :mutation_strength, 1) do
      module.mutation_strength(generation)
    else
      1.0
    end
  end

  defp apply_elitism(
         %State{population: offspring} = new_state,
         %State{scores: old_scores, config: config}
       ) do
    elite_count = Config.elite_count(config)

    if elite_count > 0 and map_size(old_scores) > 0 do
      elites =
        old_scores
        |> Enum.sort_by(fn {_entity, score} -> score end, :desc)
        |> Enum.take(elite_count)
        |> Enum.map(fn {entity, _score} -> entity end)

      final_population = Enum.take(elites ++ offspring, config.population_size)
      %{new_state | population: final_population}
    else
      new_state
    end
  end

  defp maybe_emit(%Config{metrics_enabled: true}, event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
  end

  defp maybe_emit(%Config{metrics_enabled: false}, _event, _measurements, _metadata), do: :ok

  defp log_warning(error) do
    Logger.warning(Exception.message(error), details: Map.from_struct(error))
  end

  defp parse_runtime_opts(opts) do
    with :ok <- validate_runtime_opts_shape(opts),
         :ok <- reject_unknown_runtime_keys(opts) do
      case Zoi.parse(@runtime_opts_schema, opts) do
        {:ok, parsed_opts} ->
          {:ok, parsed_opts}

        {:error, errors} ->
          {:error, Error.validation_error("invalid runtime evolve options", %{details: Zoi.treefy_errors(errors)})}
      end
    end
  end

  defp validate_runtime_opts_shape(opts) do
    if Keyword.keyword?(opts) do
      :ok
    else
      {:error, Error.validation_error("engine options must be a keyword list", %{field: :opts, value: opts})}
    end
  end

  defp reject_unknown_runtime_keys(opts) do
    allowed_keys = [:mutation, :selection, :crossover, :context]

    unknown_keys =
      opts
      |> Keyword.keys()
      |> Enum.uniq()
      |> Enum.reject(&(&1 in allowed_keys))

    if Enum.empty?(unknown_keys) do
      :ok
    else
      {:error,
       Error.validation_error("invalid runtime evolve options", %{field: :opts, unknown_keys: unknown_keys, value: opts})}
    end
  end

  defp resolve_strategy(module, :mutation) do
    case validate_mutation_module(module, []) do
      :ok ->
        {:ok, module}

      {:error, message} ->
        {:error, Error.validation_error(message, %{field: :mutation, value: module})}
    end
  end

  defp resolve_strategy(module, :selection) do
    case validate_selection_module(module, []) do
      :ok ->
        {:ok, module}

      {:error, message} ->
        {:error, Error.validation_error(message, %{field: :selection, value: module})}
    end
  end

  defp resolve_strategy(module, :crossover) do
    case validate_crossover_module(module, []) do
      :ok ->
        {:ok, module}

      {:error, message} ->
        {:error, Error.validation_error(message, %{field: :crossover, value: module})}
    end
  end

  @doc false
  @spec validate_mutation_module(module(), keyword()) :: :ok | {:error, String.t()}
  def validate_mutation_module(module, _opts) do
    validate_strategy_module(module, :mutate, 2, "mutation strategy must export mutate/2")
  end

  @doc false
  @spec validate_selection_module(module(), keyword()) :: :ok | {:error, String.t()}
  def validate_selection_module(module, _opts) do
    validate_strategy_module(module, :select, 4, "selection strategy must export select/4")
  end

  @doc false
  @spec validate_crossover_module(module(), keyword()) :: :ok | {:error, String.t()}
  def validate_crossover_module(module, _opts) do
    validate_strategy_module(module, :crossover, 3, "crossover strategy must export crossover/3")
  end

  defp validate_strategy_module(module, function, arity, message) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, function, arity) do
      :ok
    else
      {:error, message}
    end
  end

  defp validate_strategy_module(_module, _function, _arity, message), do: {:error, message}
end
