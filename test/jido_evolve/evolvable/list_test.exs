defmodule Jido.Evolve.Evolvable.ListTest do
  use ExUnit.Case, async: true

  test "to_genome/1 and from_genome/2 are identity for lists" do
    list = [1, 2, 3]
    assert Jido.Evolve.Evolvable.to_genome(list) == list
    assert Jido.Evolve.Evolvable.from_genome(list, [:a, :b]) == [:a, :b]
  end

  test "similarity/2 returns 0.0 for identical lists" do
    assert Jido.Evolve.Evolvable.similarity([1, 2, 3], [1, 2, 3]) == 0.0
  end

  test "similarity/2 returns normalized difference for equal length lists" do
    assert Jido.Evolve.Evolvable.similarity([1, 2, 3, 4], [1, 9, 3, 0]) == 0.5
  end

  test "similarity/2 returns 1.0 for different length lists" do
    assert Jido.Evolve.Evolvable.similarity([1, 2], [1, 2, 3]) == 1.0
  end
end
