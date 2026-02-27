defmodule Jido.Evolve.Mutation.BinaryTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Mutation.Binary

  test "rate 0 keeps genome unchanged" do
    genome = [1, 0, 1, 1, 0]
    assert {:ok, ^genome} = Binary.mutate(genome, rate: 0.0)
  end

  test "rate 1 flips all bits" do
    assert {:ok, [0, 1, 0, 0, 1]} = Binary.mutate([1, 0, 1, 1, 0], rate: 1.0)
  end

  test "default mutation returns same size binary vector" do
    :rand.seed(:exsplus, {9, 8, 7})
    genome = [0, 0, 1, 1, 1, 0]

    assert {:ok, mutated} = Binary.mutate(genome, [])
    assert length(mutated) == length(genome)
    assert Enum.all?(mutated, &(&1 in [0, 1]))
  end

  test "returns error for invalid genome and options" do
    assert {:error, message} = Binary.mutate([0, 1, 2], rate: 0.5)
    assert message =~ "invalid binary genome"

    assert {:error, message} = Binary.mutate([0, 1], :invalid)
    assert message =~ "expected keyword list"

    assert {:error, message} = Binary.mutate([0, 1], rate: 2.0)
    assert message =~ "invalid binary mutation opts"
  end
end
