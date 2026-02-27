defmodule Jido.Evolve.Property.PMXPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Jido.Evolve.Crossover.PMX

  property "pmx crossover preserves permutation validity" do
    check all(
            size <- StreamData.integer(2..20),
            parent1 <- permutation_of(size),
            parent2 <- permutation_of(size)
          ) do
      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      expected = Enum.to_list(0..(size - 1))

      assert Enum.sort(child1) == expected
      assert Enum.sort(child2) == expected
      assert length(child1) == size
      assert length(child2) == size
    end
  end

  defp permutation_of(size) do
    StreamData.constant(Enum.to_list(0..(size - 1)))
    |> StreamData.map(&Enum.shuffle/1)
  end
end
