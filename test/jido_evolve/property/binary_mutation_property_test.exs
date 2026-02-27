defmodule Jido.Evolve.Property.BinaryMutationPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Jido.Evolve.Mutation.Binary

  property "mutation preserves binary domain and genome length" do
    check all(
            genome <- StreamData.list_of(StreamData.member_of([0, 1]), min_length: 1, max_length: 128),
            rate <- StreamData.float(min: 0.0, max: 1.0)
          ) do
      assert {:ok, mutated} = Binary.mutate(genome, rate: rate)

      assert length(mutated) == length(genome)
      assert Enum.all?(mutated, &(&1 in [0, 1]))
    end
  end
end
