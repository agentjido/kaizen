defmodule Jido.Evolve.Crossover.UniformTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Crossover.Uniform

  test "returns original parents when lengths differ" do
    parent1 = [1, 2, 3]
    parent2 = [:a, :b]

    assert Uniform.crossover(parent1, parent2, %{}) == {parent1, parent2}
  end

  test "mixes genes from equal-length parents" do
    parent1 = [1, 2, 3, 4, 5]
    parent2 = [:a, :b, :c, :d, :e]

    :rand.seed(:exsplus, {11, 22, 33})
    {child1, child2} = Uniform.crossover(parent1, parent2, %{})

    assert length(child1) == 5
    assert length(child2) == 5

    Enum.zip([parent1, parent2, child1, child2], [parent2, parent1, child2, child1])
    |> Enum.each(fn {left, right} ->
      Enum.zip(left, right)
      |> Enum.each(fn {l, r} ->
        assert {l, r} in [{1, :a}, {2, :b}, {3, :c}, {4, :d}, {5, :e}, {:a, 1}, {:b, 2}, {:c, 3}, {:d, 4}, {:e, 5}]
      end)
    end)
  end
end
