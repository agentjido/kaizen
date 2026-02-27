defmodule Jido.Evolve do
  @moduledoc """
  Jido.Evolve is a generic evolutionary algorithm framework for Elixir.

  The canonical public API is `evolve/1`.
  """

  alias Jido.Evolve.Options

  @doc """
  Run an evolutionary search over a population.

  ## Required options

  - `:initial_population` - List of entities to evolve.
  - `:fitness` - Module implementing `evaluate/2`.

  ## Optional options

  - `:config` - `%Jido.Evolve.Config{}` or config options map/keyword.
  - `:context` - Context map passed to `fitness.evaluate/2`.
  - `:mutation` - Mutation strategy module override.
  - `:selection` - Selection strategy module override.
  - `:crossover` - Crossover strategy module override.

  ## Examples

      defmodule MyFitness do
        use Jido.Evolve.Fitness

        def evaluate(entity, _ctx), do: {:ok, String.length(entity)}
      end

      Jido.Evolve.evolve(
        initial_population: ["a", "abc", "ab"],
        fitness: MyFitness
      )
      |> Enum.to_list()
  """
  @spec evolve(keyword() | map()) :: Enumerable.t()
  def evolve(opts) when is_list(opts) or is_map(opts) do
    normalized = Options.new!(opts)

    Jido.Evolve.Engine.evolve(
      normalized.initial_population,
      normalized.config,
      normalized.fitness,
      mutation: normalized.mutation,
      selection: normalized.selection,
      crossover: normalized.crossover,
      context: normalized.context
    )
  end

  def evolve(_opts) do
    raise Jido.Evolve.Error.validation_error("evolve/1 expects a keyword list or map")
  end

  @doc """
  Get version information.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:jido_evolve, :vsn) |> List.to_string()
  end
end
