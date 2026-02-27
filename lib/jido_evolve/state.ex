defmodule Jido.Evolve.State do
  @moduledoc """
  Represents the state of an evolutionary algorithm at a given generation.

  This structure tracks the current population, their fitness scores,
  and metadata about the evolution process.
  """

  alias Jido.Evolve.Config

  @schema Zoi.struct(
            __MODULE__,
            %{
              population: Zoi.list(Zoi.any()) |> Zoi.default([]),
              scores: Zoi.map() |> Zoi.default(%{}),
              generation: Zoi.integer() |> Zoi.min(0) |> Zoi.default(0),
              best_entity: Zoi.any() |> Zoi.nullish(),
              best_score: Zoi.number() |> Zoi.default(0.0),
              average_score: Zoi.number() |> Zoi.default(0.0),
              diversity: Zoi.number() |> Zoi.default(0.0),
              fitness_history: Zoi.list(Zoi.number()) |> Zoi.default([]),
              metadata: Zoi.map() |> Zoi.default(%{}),
              config: Zoi.any()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc false
  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc """
  Create a new state from attributes.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs_map = if is_list(attrs), do: Map.new(attrs), else: attrs

    case Zoi.parse(@schema, attrs_map) do
      {:ok, state} ->
        validate_config(state)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Create a new initial state from a population and config.

  ## Examples

      iex> config = Jido.Evolve.Config.new!()
      iex> state = Jido.Evolve.State.new(["a", "b", "c"], config)
      iex> state.population
      ["a", "b", "c"]
  """
  @spec new(list(any()), Config.t()) :: t()
  def new(population, %Config{} = config) do
    new!(%{population: population, config: config})
  end

  @doc """
  Create a new state, raising on validation errors.
  """
  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, state} -> state
      {:error, error} -> raise error
    end
  end

  @doc """
  Update the state with new fitness scores.

  This recalculates the best entity, best score, and average score.
  """
  @spec update_scores(t(), map()) :: t()
  def update_scores(%__MODULE__{} = state, scores) when is_map(scores) do
    {best_entity, best_score} = find_best(scores)
    average_score = calculate_average(scores)

    %{
      state
      | scores: scores,
        best_entity: best_entity,
        best_score: best_score,
        average_score: average_score
    }
  end

  @doc """
  Update the population and advance the generation counter.
  """
  @spec next_generation(t(), list(any())) :: t()
  def next_generation(%__MODULE__{} = state, new_population) do
    new_history = [state.best_score | state.fitness_history] |> Enum.take(100)

    %{
      state
      | population: new_population,
        generation: state.generation + 1,
        scores: %{},
        best_entity: nil,
        best_score: 0.0,
        average_score: 0.0,
        fitness_history: new_history
    }
  end

  @doc """
  Calculate diversity of the current population.

  This is useful for monitoring convergence and maintaining diversity.
  """
  @spec calculate_diversity(t()) :: t()
  def calculate_diversity(%__MODULE__{population: population} = state) do
    diversity = calculate_population_diversity(population)
    %{state | diversity: diversity}
  end

  @doc """
  Add metadata to the state.
  """
  @spec put_metadata(t(), atom() | String.t(), term()) :: t()
  def put_metadata(%__MODULE__{metadata: metadata} = state, key, value) do
    %{state | metadata: Map.put(metadata, key, value)}
  end

  @doc """
  Check if termination criteria are met.
  """
  @spec terminated?(t()) :: boolean()
  def terminated?(%__MODULE__{config: config} = state) do
    criteria = config.termination_criteria
    Enum.any?(criteria, &check_criterion(state, &1))
  end

  defp validate_config(%__MODULE__{config: %Config{}} = state), do: {:ok, state}

  defp validate_config(%__MODULE__{config: invalid}) do
    {:error, %ArgumentError{message: "state config must be %Jido.Evolve.Config{}, got: #{inspect(invalid)}"}}
  end

  defp find_best(scores) when map_size(scores) == 0, do: {nil, 0.0}

  defp find_best(scores) do
    Enum.max_by(scores, fn {_entity, score} -> score end)
  end

  defp calculate_average(scores) when map_size(scores) == 0, do: 0.0

  defp calculate_average(scores) do
    sum = scores |> Map.values() |> Enum.sum()
    sum / map_size(scores)
  end

  defp calculate_population_diversity(population) when length(population) < 2 do
    0.0
  end

  defp calculate_population_diversity(population) do
    pop_size = length(population)
    max_samples = 1000

    if pop_size < 10 do
      pairs = for i <- population, j <- population, i != j, do: {i, j}

      if Enum.empty?(pairs) do
        0.0
      else
        total_similarity =
          pairs
          |> Enum.map(fn {a, b} -> Jido.Evolve.Evolvable.similarity(a, b) end)
          |> Enum.sum()

        total_similarity / length(pairs)
      end
    else
      sample_count = min(max_samples, div(pop_size * pop_size, 10))

      sampled_similarities =
        1..sample_count
        |> Enum.map(fn _ ->
          i = Enum.random(population)
          j = Enum.random(population)

          if i == j do
            candidates = population -- [i]

            if Enum.empty?(candidates) do
              0.0
            else
              Jido.Evolve.Evolvable.similarity(i, Enum.random(candidates))
            end
          else
            Jido.Evolve.Evolvable.similarity(i, j)
          end
        end)

      if Enum.empty?(sampled_similarities) do
        0.0
      else
        Enum.sum(sampled_similarities) / length(sampled_similarities)
      end
    end
  end

  defp check_criterion(state, {:max_generations, max_gen}) do
    state.generation >= max_gen
  end

  defp check_criterion(state, {:target_fitness, target}) do
    state.best_score >= target
  end

  defp check_criterion(state, {:no_improvement, generations}) do
    if length(state.fitness_history) < generations do
      false
    else
      recent_scores = Enum.take(state.fitness_history, generations)

      if length(recent_scores) < 2 do
        false
      else
        mean = Enum.sum(recent_scores) / length(recent_scores)

        variance =
          recent_scores
          |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(recent_scores))

        variance < 0.0001
      end
    end
  end

  defp check_criterion(_state, _criterion), do: false
end
