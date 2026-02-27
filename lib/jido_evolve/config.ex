defmodule Jido.Evolve.Config do
  @moduledoc """
  Canonical configuration structure for evolutionary algorithms.

  This module uses Zoi for validation and provides sensible defaults.
  """

  import Bitwise

  @termination_criteria_schema Zoi.list(Zoi.tuple({Zoi.atom(), Zoi.any()}))

  @schema Zoi.struct(
            __MODULE__,
            %{
              population_size: Zoi.integer() |> Zoi.min(1) |> Zoi.default(100),
              generations: Zoi.integer() |> Zoi.min(1) |> Zoi.default(1000),
              mutation_rate: Zoi.number() |> Zoi.min(0.0) |> Zoi.max(1.0) |> Zoi.default(0.1),
              crossover_rate: Zoi.number() |> Zoi.min(0.0) |> Zoi.max(1.0) |> Zoi.default(0.7),
              elitism_rate: Zoi.number() |> Zoi.min(0.0) |> Zoi.max(1.0) |> Zoi.default(0.05),
              max_concurrency: Zoi.integer() |> Zoi.min(1) |> Zoi.default(System.schedulers_online()),
              selection_strategy: Zoi.atom() |> Zoi.default(Jido.Evolve.Selection.Tournament),
              mutation_strategy: Zoi.atom() |> Zoi.default(Jido.Evolve.Mutation.Text),
              crossover_strategy: Zoi.atom() |> Zoi.default(Jido.Evolve.Crossover.String),
              termination_criteria: @termination_criteria_schema |> Zoi.default([]),
              checkpoint_interval: Zoi.integer() |> Zoi.min(1) |> Zoi.nullish(),
              metrics_enabled: Zoi.boolean() |> Zoi.default(true),
              random_seed: Zoi.integer() |> Zoi.nullish(),
              tournament_size: Zoi.integer() |> Zoi.min(1) |> Zoi.default(2),
              selection_pressure: Zoi.number() |> Zoi.min(0.0) |> Zoi.default(1.0),
              evaluation_timeout:
                Zoi.union([
                  Zoi.integer() |> Zoi.min(1),
                  Zoi.literal(:infinity)
                ])
                |> Zoi.default(30_000)
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
  Create a new configuration with validation.

  ## Examples

      iex> {:ok, config} = Jido.Evolve.Config.new(population_size: 50)
      iex> config.population_size
      50

      iex> {:error, _error} = Jido.Evolve.Config.new(population_size: -1)
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ [])

  def new(opts) when is_list(opts) or is_map(opts) do
    opts_map = normalize_opts(opts)

    case Zoi.parse(@schema, opts_map) do
      {:ok, config} ->
        {:ok, config}

      {:error, error} ->
        {:error, error}
    end
  end

  def new(_opts), do: {:error, %ArgumentError{message: "config options must be a keyword list or map"}}

  @doc """
  Create a new configuration, raising on validation errors.

  ## Examples

      iex> config = Jido.Evolve.Config.new!(population_size: 50)
      iex> config.population_size
      50
  """
  @spec new!(keyword() | map()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end

  @doc """
  Get the number of elite entities to preserve.
  """
  @spec elite_count(t()) :: non_neg_integer()
  def elite_count(%__MODULE__{population_size: pop_size, elitism_rate: rate}) do
    if rate > 0.0, do: max(1, round(pop_size * rate)), else: 0
  end

  @doc """
  Initialize random seed if configured.

  Uses explicit :exs1024 algorithm with deterministic seed tuple for reproducibility
  across OTP versions.
  """
  @spec init_random_seed(t()) :: :ok
  def init_random_seed(%__MODULE__{random_seed: nil}), do: :ok

  @spec init_random_seed(t()) :: :ok
  def init_random_seed(%__MODULE__{random_seed: seed}) when is_integer(seed) do
    :rand.seed(:exs1024, {seed, seed <<< 1, seed <<< 2})
    :ok
  end

  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_opts(opts) when is_map(opts), do: opts
end
