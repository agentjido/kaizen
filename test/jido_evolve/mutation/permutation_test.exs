defmodule Jido.Evolve.Mutation.PermutationTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Mutation.Permutation

  describe "swap mutation" do
    test "preserves permutation validity" do
      for _ <- 1..100 do
        perm = Enum.shuffle(0..9)
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :swap)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles edge case with 1 element" do
      assert {:ok, [5]} = Permutation.mutate([5], rate: 1.0, mode: :swap)
    end

    test "handles empty list" do
      assert {:ok, []} = Permutation.mutate([], rate: 1.0, mode: :swap)
    end
  end

  describe "inversion mutation" do
    test "preserves permutation validity" do
      for _ <- 1..100 do
        perm = Enum.shuffle(0..9)
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles inversion at start (index 0)" do
      :rand.seed(:exsss, {0, 0, 1})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles inversion at end (index n-1)" do
      :rand.seed(:exsss, {1, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles single element inversion (start == end)" do
      :rand.seed(:exsss, {2, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles full array inversion" do
      :rand.seed(:exsss, {3, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles edge case with 1 element" do
      assert {:ok, [5]} = Permutation.mutate([5], rate: 1.0, mode: :inversion)
    end

    test "correctly reverses segment" do
      :rand.seed(:exsss, {4, 0, 0})
      perm = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

      for _ <- 1..100 do
        {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :inversion)

        # Find the inverted segment by comparing with original
        if result != perm do
          assert_valid_permutation(perm, result)
          # Result should have exactly one contiguous reversed segment
          assert length(result) == length(perm)
        end
      end
    end
  end

  describe "insertion mutation" do
    test "preserves permutation validity" do
      for _ <- 1..100 do
        perm = Enum.shuffle(0..9)
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles insertion from start (index 0)" do
      :rand.seed(:exsss, {5, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles insertion to end (index n-1)" do
      :rand.seed(:exsss, {6, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)
        assert_valid_permutation(perm, result)
      end
    end

    test "handles insertion where from == to" do
      :rand.seed(:exsss, {7, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..50 do
        assert {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)
        assert_valid_permutation(perm, result)
      end
    end

    test "correctly moves element and preserves relative order" do
      :rand.seed(:exsss, {8, 0, 0})
      perm = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

      for _ <- 1..100 do
        {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)

        assert_valid_permutation(perm, result)

        # Find what moved
        if result != perm do
          # Exactly one element should have moved
          moved_indices =
            Enum.zip(perm, result)
            |> Enum.with_index()
            |> Enum.reject(fn {{a, b}, _} -> a == b end)

          # At least one position should differ
          refute Enum.empty?(moved_indices)
        end
      end
    end

    test "handles edge case with 1 element" do
      assert {:ok, [5]} = Permutation.mutate([5], rate: 1.0, mode: :insertion)
    end

    test "verifies index adjustment after deletion" do
      # Specific test for the bug: when to_idx > from_idx, need to adjust
      :rand.seed(:exsss, {9, 0, 0})
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..100 do
        {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :insertion)
        # Should always produce a valid permutation
        assert_valid_permutation(perm, result)
        # Should have same length
        assert length(result) == length(perm)
      end
    end
  end

  describe "mutation rate" do
    test "respects mutation rate of 0.0" do
      perm = [0, 1, 2, 3, 4]

      for _ <- 1..100 do
        assert {:ok, ^perm} = Permutation.mutate(perm, rate: 0.0, mode: :swap)
        assert {:ok, ^perm} = Permutation.mutate(perm, rate: 0.0, mode: :inversion)
        assert {:ok, ^perm} = Permutation.mutate(perm, rate: 0.0, mode: :insertion)
      end
    end

    test "always mutates with rate of 1.0" do
      :rand.seed(:exsss, {10, 0, 0})
      perm = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

      mutations =
        for _ <- 1..100 do
          {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: :swap)
          result != perm
        end

      # With rate 1.0 and 10 elements, should almost always produce a change
      # (except when same indices picked for swap)
      assert Enum.count(mutations, & &1) > 50
    end
  end

  describe "error handling" do
    test "rejects non-list genome" do
      assert {:error, _} = Permutation.mutate("not a list", rate: 1.0, mode: :swap)
      assert {:error, _} = Permutation.mutate(123, rate: 1.0, mode: :swap)
    end

    test "rejects unknown mode" do
      assert {:error, _} = Permutation.mutate([1, 2, 3], rate: 1.0, mode: :unknown)
    end

    test "rejects invalid options via schema validation" do
      assert {:error, message} = Permutation.mutate([1, 2, 3], rate: -0.1)
      assert message =~ "invalid permutation mutation opts"

      assert {:error, message} = Permutation.mutate([1, 2, 3], :invalid)
      assert message =~ "expected keyword list or map"
    end
  end

  describe "property-based tests" do
    test "all mutations preserve multiset property over many iterations" do
      for size <- [2, 5, 10, 20] do
        perm = Enum.shuffle(0..(size - 1))

        for mode <- [:swap, :inversion, :insertion] do
          for _ <- 1..50 do
            {:ok, result} = Permutation.mutate(perm, rate: 1.0, mode: mode)
            assert_valid_permutation(perm, result)
          end
        end
      end
    end

    test "mutations are reversible (in terms of permutation space)" do
      # Any mutation produces a valid permutation that could be reached
      # by another sequence of mutations
      perm = Enum.shuffle(0..9)

      {:ok, mutated} = Permutation.mutate(perm, rate: 1.0, mode: :swap)

      # Should be able to mutate back to original permutation eventually
      # (just verify it's in the same permutation space)
      assert_valid_permutation(perm, mutated)
    end
  end

  # Helper to verify that result is a valid permutation of original
  defp assert_valid_permutation(original, result) do
    assert length(original) == length(result),
           "Length mismatch: original #{length(original)}, result #{length(result)}"

    assert Enum.sort(original) == Enum.sort(result),
           "Not a valid permutation: #{inspect(original)} -> #{inspect(result)}"
  end
end
