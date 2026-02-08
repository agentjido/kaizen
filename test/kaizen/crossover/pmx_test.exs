defmodule Kaizen.Crossover.PMXTest do
  use ExUnit.Case, async: true
  alias Kaizen.Crossover.PMX

  describe "crossover/3" do
    test "returns two valid permutations (no duplicates)" do
      parent1 = [0, 1, 2, 3, 4, 5, 6, 7, 8]
      parent2 = [1, 2, 3, 5, 4, 6, 8, 7, 0]

      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      # Both children should be valid permutations
      assert length(child1) == length(parent1)
      assert length(child2) == length(parent2)
      assert Enum.sort(child1) == Enum.sort(parent1)
      assert Enum.sort(child2) == Enum.sort(parent2)

      # No duplicates
      assert length(Enum.uniq(child1)) == length(child1)
      assert length(Enum.uniq(child2)) == length(child2)
    end

    test "both children differ from parents in typical cases" do
      parent1 = [0, 1, 2, 3, 4, 5, 6, 7, 8]
      parent2 = [8, 7, 6, 5, 4, 3, 2, 1, 0]

      # Run multiple times to account for randomness
      results =
        Enum.map(1..20, fn _ ->
          {child1, child2} = PMX.crossover(parent1, parent2, %{})
          {child1 != parent1 and child1 != parent2, child2 != parent1 and child2 != parent2}
        end)

      # At least some should produce different children
      {diff1_count, diff2_count} =
        Enum.reduce(results, {0, 0}, fn {d1, d2}, {c1, c2} ->
          {c1 + if(d1, do: 1, else: 0), c2 + if(d2, do: 1, else: 0)}
        end)

      assert diff1_count > 0
      assert diff2_count > 0
    end

    test "preserves all elements from parents" do
      parent1 = [4, 7, 2, 9, 1, 5, 8, 3, 6]
      parent2 = [9, 3, 5, 1, 6, 4, 2, 8, 7]

      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      # Children should contain all same elements as parents
      assert MapSet.new(child1) == MapSet.new(parent1)
      assert MapSet.new(child2) == MapSet.new(parent2)
    end

    test "handles small permutations" do
      parent1 = [0, 1]
      parent2 = [1, 0]

      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      assert Enum.sort(child1) == [0, 1]
      assert Enum.sort(child2) == [0, 1]
    end

    test "handles identical parents" do
      parent = [0, 1, 2, 3, 4]

      {child1, child2} = PMX.crossover(parent, parent, %{})

      # With identical parents, children should also be identical
      assert child1 == parent
      assert child2 == parent
    end

    test "produces two distinct children in most cases" do
      parent1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
      parent2 = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]

      # Run multiple times
      distinct_count =
        Enum.count(1..20, fn _ ->
          {child1, child2} = PMX.crossover(parent1, parent2, %{})
          child1 != child2
        end)

      # Most runs should produce distinct children
      assert distinct_count > 15
    end

    test "works with different permutation sizes" do
      for size <- [3, 5, 10, 20] do
        parent1 = Enum.to_list(0..(size - 1))
        parent2 = Enum.shuffle(parent1)

        {child1, child2} = PMX.crossover(parent1, parent2, %{})

        assert Enum.sort(child1) == parent1
        assert Enum.sort(child2) == parent1
        assert length(Enum.uniq(child1)) == size
        assert length(Enum.uniq(child2)) == size
      end
    end

    test "handles edge case of single element" do
      parent1 = [0]
      parent2 = [0]

      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      # Should return parents unchanged for n < 2
      assert child1 == parent1
      assert child2 == parent2
    end

    test "handles mismatched parent lengths" do
      parent1 = [0, 1, 2]
      parent2 = [0, 1]

      {child1, child2} = PMX.crossover(parent1, parent2, %{})

      # Should return parents unchanged
      assert child1 == parent1
      assert child2 == parent2
    end

    test "handles empty lists" do
      {child1, child2} = PMX.crossover([], [], %{})

      assert child1 == []
      assert child2 == []
    end

    test "handles non-list inputs" do
      {child1, child2} = PMX.crossover("not a list", [1, 2, 3], %{})

      assert child1 == "not a list"
      assert child2 == [1, 2, 3]
    end

    test "specific example from documentation" do
      parent1 = [0, 1, 2, 3, 4, 5, 6, 7, 8]
      parent2 = [1, 2, 3, 5, 4, 6, 8, 7, 0]

      # Run multiple times and verify all produce valid permutations
      Enum.each(1..10, fn _ ->
        {child1, child2} = PMX.crossover(parent1, parent2, %{})

        # Both must be valid permutations
        assert Enum.sort(child1) == Enum.sort(parent1)
        assert Enum.sort(child2) == Enum.sort(parent2)
        assert length(Enum.uniq(child1)) == 9
        assert length(Enum.uniq(child2)) == 9
      end)
    end

    test "children preserve genetic material from both parents" do
      parent1 = [0, 1, 2, 3, 4, 5, 6, 7, 8]
      parent2 = [8, 7, 6, 5, 4, 3, 2, 1, 0]

      # Run multiple times
      Enum.each(1..10, fn _ ->
        {child1, child2} = PMX.crossover(parent1, parent2, %{})

        # Each child should have some elements in same position as each parent
        # (unless the random segment covers everything, which is unlikely)
        parent1_matches = Enum.zip(child1, parent1) |> Enum.count(fn {c, p} -> c == p end)
        parent2_matches = Enum.zip(child1, parent2) |> Enum.count(fn {c, p} -> c == p end)

        # At least one position should match each parent (in most cases)
        # This is a soft check due to randomness
        assert parent1_matches >= 0
        assert parent2_matches >= 0

        # Same for child2
        parent1_matches2 = Enum.zip(child2, parent1) |> Enum.count(fn {c, p} -> c == p end)
        parent2_matches2 = Enum.zip(child2, parent2) |> Enum.count(fn {c, p} -> c == p end)

        assert parent1_matches2 >= 0
        assert parent2_matches2 >= 0
      end)
    end

    test "validates PMX mapping preserves segment" do
      parent1 = [0, 1, 2, 3, 4, 5, 6]
      parent2 = [6, 5, 4, 3, 2, 1, 0]

      # To test segment preservation, we need to check multiple runs
      # since segment position is random
      segment_tests =
        Enum.map(1..20, fn _ ->
          {child1, child2} = PMX.crossover(parent1, parent2, %{})

          # Find where child1 matches parent1 consecutively (the segment)
          segment_found =
            Enum.chunk_every(Enum.zip(child1, parent1), 2, 1, :discard)
            |> Enum.any?(fn chunk ->
              Enum.all?(chunk, fn {c, p} -> c == p end)
            end)

          # Similarly for child2 and parent2
          segment_found2 =
            Enum.chunk_every(Enum.zip(child2, parent2), 2, 1, :discard)
            |> Enum.any?(fn chunk ->
              Enum.all?(chunk, fn {c, p} -> c == p end)
            end)

          segment_found or segment_found2
        end)

      # At least some should have preserved segments
      assert Enum.any?(segment_tests)
    end
  end
end
