defmodule Jido.Evolve.Crossover.MapUniform do
  @moduledoc """
  Uniform crossover for map genomes.

  Selects each key's value from one of the parents randomly.
  For numeric lists, performs one-point crossover on the list.

  Handles asymmetric parent keys by taking the union of all keys.
  Missing keys are treated as nil during crossover.

  ## Example

      parent1 = %{lr: 0.01, layers: [128, 64], act: :relu}
      parent2 = %{lr: 0.001, layers: [256, 128, 64], act: :tanh}
      
      # Possible child:
      %{lr: 0.001, layers: [128, 64, 64], act: :relu}
  """

  @behaviour Jido.Evolve.Crossover

  @impl true
  def crossover(parent1, parent2, _config) when is_map(parent1) and is_map(parent2) do
    # Build union of keys from both parents
    keys =
      MapSet.union(
        MapSet.new(Map.keys(parent1)),
        MapSet.new(Map.keys(parent2))
      )

    child1 =
      keys
      |> Enum.map(fn key ->
        val1 = Map.get(parent1, key)
        val2 = Map.get(parent2, key)
        {key, crossover_value(val1, val2)}
      end)
      |> Map.new()

    child2 =
      keys
      |> Enum.map(fn key ->
        val1 = Map.get(parent1, key)
        val2 = Map.get(parent2, key)
        {key, crossover_value(val2, val1)}
      end)
      |> Map.new()

    {child1, child2}
  end

  def crossover(parent1, parent2, _config) do
    # Invalid types - return parents unchanged
    {parent1, parent2}
  end

  # Crossover for lists (one-point crossover)
  defp crossover_value(list1, list2) when is_list(list1) and is_list(list2) do
    if Enum.empty?(list1) or Enum.empty?(list2) do
      Enum.random([list1, list2])
    else
      len = min(length(list1), length(list2))
      point = :rand.uniform(len)
      Enum.take(list1, point) ++ Enum.drop(list2, point)
    end
  end

  # Handle nil values (when key exists in only one parent)
  defp crossover_value(nil, val2), do: val2
  defp crossover_value(val1, nil), do: val1

  # Uniform selection for scalars
  defp crossover_value(val1, val2) do
    Enum.random([val1, val2])
  end
end
