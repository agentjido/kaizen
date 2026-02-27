defmodule Jido.Evolve.Mutation.AdaptiveTextTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Mutation.AdaptiveText

  test "uses high mutation rate before threshold and low mutation rate after threshold" do
    :rand.seed(:exsplus, {1, 2, 3})
    assert {:ok, low_fitness_mutated} = AdaptiveText.mutate("hello", best_fitness: 0.1, high_rate: 1.0, low_rate: 0.0)
    assert low_fitness_mutated != "hello"

    :rand.seed(:exsplus, {1, 2, 3})
    assert {:ok, high_fitness_mutated} = AdaptiveText.mutate("hello", best_fitness: 1.0, high_rate: 1.0, low_rate: 0.0)
    assert high_fitness_mutated == "hello"
  end

  test "returns error for non-string entities" do
    assert {:error, message} = AdaptiveText.mutate(123, [])
    assert message =~ "only works with string entities"
  end

  test "mutation_strength/1 decreases with generation and has floor" do
    assert AdaptiveText.mutation_strength(0) == 1.0
    assert AdaptiveText.mutation_strength(100) < 1.0
    assert AdaptiveText.mutation_strength(10_000) == 0.1
  end
end
