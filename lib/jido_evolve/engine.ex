defmodule Jido.Evolve.Engine do
  @moduledoc """
  Core evolutionary algorithm engine.

  Provides a Stream-based interface for running evolutionary algorithms
  with pluggable strategies for fitness, mutation, selection, and crossover.
  """

  require Logger

  # Logger helper - using Logger.warning (Elixir 1.11+)
  # For cross-version compatibility with older Elixir, this could be made conditional
  defp log_warning(msg, meta) do
    Logger.warning(msg, meta)
  end

  @doc """
  Run an evolutionary algorithm with the given configuration.

  Returns a Stream of `Jido.Evolve.State` structs representing each generation.
  The Stream is lazy, so generations are only computed when consumed.

  ## Parameters

  - `initial_population` - List of initial entities
  - `config` - `Jido.Evolve.Config` struct with algorithm parameters
  - `fitness_module` - Module implementing `Jido.Evolve.Fitness` behaviour
  - `evolvable_module` - Module implementing `Jido.Evolve.Evolvable` protocol for the entity type
  - `opts` - Additional options

  ## Options

  - `:mutation_module` - Module implementing `Jido.Evolve.Mutation` (default from config)
  - `:selection_module` - Module implementing `Jido.Evolve.Selection` (default from config)
  - `:context` - Context map passed to fitness evaluation

  ## Examples

      config = Jido.Evolve.Config.new!(population_size: 100, generations: 50)
      
      Jido.Evolve.Engine.evolve(
        ["initial", "population"],
        config,
        MyFitness,
        Jido.Evolve.Evolvable.String
      )
      |> Enum.take(10)  # Run for 10 generations
      |> List.last()    # Get final state
  """
  @spec evolve(list(any()), Jido.Evolve.Config.t(), module(), module(), keyword()) ::
          Enumerable.t()
  def evolve(
        initial_population,
        %Jido.Evolve.Config{} = config,
        fitness_module,
        evolvable_module,
        opts \\ []
      ) do
    mutation_module = Keyword.get(opts, :mutation_module, config.mutation_strategy)
    selection_module = Keyword.get(opts, :selection_module, config.selection_strategy)
    crossover_module = Keyword.get(opts, :crossover_module, config.crossover_strategy)
    context = Keyword.get(opts, :context, %{})

    # Initialize random seed if configured
    Jido.Evolve.Config.init_random_seed(config)

    # Create initial state and evaluate initial population
    initial_state =
      initial_population
      |> Jido.Evolve.State.new(config)
      |> evaluate_population(fitness_module, context)
      |> calculate_diversity(evolvable_module)

    # Emit telemetry
    :telemetry.execute(
      [:jido_evolve, :evolution, :start],
      %{population_size: length(initial_population)},
      %{config: config}
    )

    Stream.unfold(initial_state, fn state ->
      if Jido.Evolve.State.terminated?(state) or state.generation >= config.generations do
        :telemetry.execute([:jido_evolve, :evolution, :stop], %{generation: state.generation}, %{
          state: state
        })

        nil
      else
        next_state =
          evolution_step(
            state,
            fitness_module,
            evolvable_module,
            mutation_module,
            selection_module,
            crossover_module,
            context
          )

        {state, next_state}
      end
    end)
  end

  @doc """
  Perform a single evolution step.

  This function handles one complete generation:
  1. Evaluate fitness of current population
  2. Select parents for next generation
  3. Create offspring through mutation and crossover
  4. Apply elitism to preserve best entities
  """
  def evolution_step(
        state,
        fitness_module,
        evolvable_module,
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

    :telemetry.execute([:jido_evolve, :generation, :start], %{generation: generation}, %{})

    new_state =
      state
      |> select_and_breed(
        selection_module,
        mutation_module,
        crossover_module,
        evolvable_module,
        context
      )
      |> apply_elitism(state)
      |> (fn new_state -> Jido.Evolve.State.next_generation(new_state, new_state.population) end).()
      |> evaluate_population(fitness_module, context)
      |> calculate_diversity(evolvable_module)

    Logger.debug("Completed generation #{generation}",
      generation: generation,
      best_score: new_state.best_score,
      diversity: new_state.diversity
    )

    :telemetry.execute(
      [:jido_evolve, :generation, :stop],
      %{generation: generation, best_score: new_state.best_score},
      %{state: new_state}
    )

    new_state
  end

  # Private functions

  defp evaluate_population(
         %Jido.Evolve.State{population: population, config: config} = state,
         fitness_module,
         context
       ) do
    Logger.debug("Evaluating population", population_size: length(population))

    :telemetry.execute(
      [:jido_evolve, :evaluation, :start],
      %{population_size: length(population)},
      %{}
    )

    # Use Task.async_stream for parallel evaluation
    scores =
      population
      |> Task.async_stream(
        fn entity ->
          case fitness_module.evaluate(entity, context) do
            {:ok, score} when is_number(score) ->
              {entity, score}

            {:ok, %{score: score}} ->
              {entity, score}

            {:error, reason} ->
              log_warning("Fitness evaluation failed", error: reason)
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
          log_warning("Fitness evaluation timed out", reason: reason)
          acc
      end)

    Logger.debug("Population evaluated", evaluated_count: map_size(scores))

    :telemetry.execute(
      [:jido_evolve, :evaluation, :stop],
      %{evaluated_count: map_size(scores)},
      %{}
    )

    Jido.Evolve.State.update_scores(state, scores)
  end

  defp calculate_diversity(state, evolvable_module) do
    Jido.Evolve.State.calculate_diversity(state, evolvable_module)
  end

  defp select_and_breed(
         %Jido.Evolve.State{population: population, scores: scores, config: config} = state,
         selection_module,
         mutation_module,
         crossover_module,
         _evolvable_module,
         _context
       ) do
    # Determine how many offspring to create (accounting for elitism)
    elite_count = Jido.Evolve.Config.elite_count(config)
    offspring_count = config.population_size - elite_count

    Logger.debug("Selecting and breeding",
      offspring_count: offspring_count,
      elite_count: elite_count
    )

    # Select parents - need pairs for crossover
    selection_opts = [
      tournament_size: config.tournament_size,
      pressure: config.selection_pressure
    ]

    all_parents = selection_module.select(population, scores, offspring_count * 2, selection_opts)

    # Group parents into pairs and apply crossover/mutation
    offspring =
      all_parents
      |> Enum.chunk_every(2)
      |> Enum.flat_map(fn
        [parent1, parent2] ->
          # Apply crossover based on crossover rate
          {child1, child2} =
            if :rand.uniform() < config.crossover_rate do
              crossover_module.crossover(parent1, parent2, config)
            else
              {parent1, parent2}
            end

          # Apply mutation to both children
          children = [child1, child2]

          Enum.map(children, fn child ->
            # Call mutate unconditionally - module owns probability logic
            mutation_opts = [
              rate: config.mutation_rate,
              strength: mutation_module.mutation_strength(state.generation),
              best_fitness: state.best_score || 0.0
            ]

            case mutation_module.mutate(child, mutation_opts) do
              {:ok, mutated} ->
                mutated

              {:error, reason} ->
                log_warning("Mutation failed", error: reason)
                child
            end
          end)

        [single_parent] ->
          # Handle odd number case - just mutate the single parent
          mutation_opts = [
            rate: config.mutation_rate,
            strength: mutation_module.mutation_strength(state.generation),
            best_fitness: state.best_score || 0.0
          ]

          case mutation_module.mutate(single_parent, mutation_opts) do
            {:ok, mutated} ->
              [mutated]

            {:error, reason} ->
              log_warning("Mutation failed", error: reason)
              [single_parent]
          end
      end)
      # Ensure we don't exceed desired offspring count
      |> Enum.take(offspring_count)

    Logger.debug("Breeding complete", offspring_count: length(offspring))

    %{state | population: offspring}
  end

  defp apply_elitism(
         %Jido.Evolve.State{population: offspring} = new_state,
         %Jido.Evolve.State{population: _old_population, scores: old_scores, config: config}
       ) do
    elite_count = Jido.Evolve.Config.elite_count(config)

    if elite_count > 0 and map_size(old_scores) > 0 do
      # Get the best entities from the previous generation
      elites =
        old_scores
        |> Enum.sort_by(fn {_entity, score} -> score end, :desc)
        |> Enum.take(elite_count)
        |> Enum.map(fn {entity, _score} -> entity end)

      # Replace worst offspring with elites
      final_population = Enum.take(elites ++ offspring, config.population_size)
      %{new_state | population: final_population}
    else
      new_state
    end
  end
end
