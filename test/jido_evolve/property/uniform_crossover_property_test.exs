defmodule Jido.Evolve.Property.UniformCrossoverPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Jido.Evolve.Crossover.Uniform

  property "children keep length and only swap corresponding genes" do
    check all(
            size <- StreamData.integer(1..40),
            parent1 <- StreamData.list_of(StreamData.integer(), length: size),
            parent2 <- StreamData.list_of(StreamData.integer(), length: size)
          ) do
      {child1, child2} = Uniform.crossover(parent1, parent2, %{})

      assert length(child1) == size
      assert length(child2) == size

      Enum.zip(Enum.zip(parent1, parent2), Enum.zip(child1, child2))
      |> Enum.each(fn {{gene1, gene2}, {child_gene1, child_gene2}} ->
        assert {child_gene1, child_gene2} in [{gene1, gene2}, {gene2, gene1}]
      end)
    end
  end
end
