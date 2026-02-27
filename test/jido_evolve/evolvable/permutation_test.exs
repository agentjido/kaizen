defmodule Jido.Evolve.Evolvable.PermutationTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Evolvable.Permutation

  test "valid?/1 returns true for proper permutations" do
    assert Permutation.valid?([0, 1, 2, 3])
    assert Permutation.valid?([3, 2, 1, 0])
  end

  test "valid?/1 returns false for duplicates or gaps" do
    refute Permutation.valid?([0, 1, 1, 3])
    refute Permutation.valid?([1, 2, 3, 4])
  end

  test "new/1 returns a valid permutation of requested size" do
    permutation = Permutation.new(6)
    assert length(permutation) == 6
    assert Permutation.valid?(permutation)
  end

  test "new/1 returns error for invalid sizes" do
    assert {:error, _} = Permutation.new(0)
    assert {:error, _} = Permutation.new(-1)
    assert {:error, _} = Permutation.new("6")
  end
end
