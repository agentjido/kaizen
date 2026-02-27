defmodule Jido.Evolve.Options do
  @moduledoc """
  Canonical option validation and normalization for `Jido.Evolve.evolve/1`.
  """

  alias Jido.Evolve.{Config, Error}

  @schema Zoi.struct(
            __MODULE__,
            %{
              initial_population: Zoi.list(Zoi.any()),
              fitness: Zoi.atom(),
              config: Zoi.any() |> Zoi.nullish(),
              context: Zoi.map() |> Zoi.default(%{}),
              mutation: Zoi.atom() |> Zoi.nullish(),
              selection: Zoi.atom() |> Zoi.nullish(),
              crossover: Zoi.atom() |> Zoi.nullish()
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
  Validate and normalize public evolve options.
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, Exception.t()}
  def new(opts) when is_list(opts) or is_map(opts) do
    opts_map = normalize_opts(opts)

    with {:ok, parsed} <- parse(opts_map),
         :ok <- validate_population(parsed.initial_population),
         :ok <- validate_fitness(parsed.fitness),
         {:ok, config} <- normalize_config(parsed.config),
         {:ok, mutation} <- resolve_strategy(parsed.mutation || config.mutation_strategy, :mutation),
         {:ok, selection} <- resolve_strategy(parsed.selection || config.selection_strategy, :selection),
         {:ok, crossover} <- resolve_strategy(parsed.crossover || config.crossover_strategy, :crossover) do
      {:ok,
       %{
         parsed
         | config: config,
           mutation: mutation,
           selection: selection,
           crossover: crossover
       }}
    end
  end

  def new(_opts) do
    {:error, Error.validation_error("evolve/1 options must be a keyword list or map")}
  end

  @doc """
  Validate and normalize options, raising on invalid input.
  """
  @spec new!(keyword() | map()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, normalized} ->
        normalized

      {:error, error} ->
        raise error
    end
  end

  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_opts(opts) when is_map(opts), do: opts

  defp parse(opts_map) do
    case Zoi.parse(@schema, opts_map) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, reason} ->
        {:error, Error.validation_error("invalid evolve options", %{details: reason})}
    end
  end

  defp validate_population(population) do
    if Enum.empty?(population) do
      {:error, Error.validation_error("initial_population must not be empty", %{field: :initial_population})}
    else
      :ok
    end
  end

  defp validate_fitness(module) do
    cond do
      not is_atom(module) ->
        {:error, Error.validation_error("fitness must be a module", %{field: :fitness, value: module})}

      not module_exports?(module, :evaluate, 2) ->
        {:error, Error.validation_error("fitness module must export evaluate/2", %{field: :fitness, value: module})}

      true ->
        :ok
    end
  end

  defp normalize_config(nil), do: {:ok, Config.new!()}
  defp normalize_config(%Config{} = config), do: {:ok, config}

  defp normalize_config(config_opts) when is_list(config_opts) or is_map(config_opts) do
    case Config.new(config_opts) do
      {:ok, config} ->
        {:ok, config}

      {:error, reason} ->
        {:error, Error.config_error("invalid config for evolve/1", %{details: reason})}
    end
  end

  defp normalize_config(other) do
    {:error, Error.config_error("config must be nil, map, keyword list, or %Jido.Evolve.Config{}", %{value: other})}
  end

  defp resolve_strategy(module, :mutation) do
    if module_exports?(module, :mutate, 2) do
      {:ok, module}
    else
      {:error, Error.validation_error("mutation strategy must export mutate/2", %{field: :mutation, value: module})}
    end
  end

  defp resolve_strategy(module, :selection) do
    if module_exports?(module, :select, 4) do
      {:ok, module}
    else
      {:error, Error.validation_error("selection strategy must export select/4", %{field: :selection, value: module})}
    end
  end

  defp resolve_strategy(module, :crossover) do
    if module_exports?(module, :crossover, 3) do
      {:ok, module}
    else
      {:error,
       Error.validation_error("crossover strategy must export crossover/3", %{field: :crossover, value: module})}
    end
  end

  defp module_exports?(module, function, arity) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp module_exports?(_module, _function, _arity), do: false
end
