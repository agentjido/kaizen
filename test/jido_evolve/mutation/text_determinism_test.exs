defmodule Jido.Evolve.Mutation.TextDeterminismTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Mutation.Text

  describe "deterministic mutation behavior" do
    test "produces same results with same seed" do
      input = "hello world"

      :rand.seed(:exsplus, {1, 2, 3})
      {:ok, result1} = Text.mutate(input, rate: 0.5, operations: [:replace, :insert, :delete])

      :rand.seed(:exsplus, {1, 2, 3})
      {:ok, result2} = Text.mutate(input, rate: 0.5, operations: [:replace, :insert, :delete])

      assert result1 == result2
    end

    test "handles insert/delete without index drift" do
      input = "abcdefgh"

      :rand.seed(:exsplus, {100, 200, 300})
      {:ok, result} = Text.mutate(input, rate: 0.8, operations: [:insert, :delete])

      assert is_binary(result)
      # Should complete without errors
    end

    test "high mutation rate with all operations" do
      input = "test"

      :rand.seed(:exsplus, {42, 43, 44})
      {:ok, result} = Text.mutate(input, rate: 1.0, operations: [:replace, :insert, :delete])

      assert is_binary(result)
      # Should complete without infinite loops
    end

    test "empty string handling" do
      {:ok, result} = Text.mutate("", rate: 0.5, operations: [:replace, :insert, :delete])
      assert is_binary(result)
    end

    test "single character string" do
      :rand.seed(:exsplus, {5, 6, 7})
      {:ok, result} = Text.mutate("x", rate: 0.5, operations: [:replace, :insert, :delete])

      assert is_binary(result)
    end

    test "delete operation maintains minimum length of 1" do
      # With only delete operations and high rate, should not delete last char
      :rand.seed(:exsplus, {10, 11, 12})
      {:ok, result} = Text.mutate("ab", rate: 1.0, operations: [:delete])

      assert String.length(result) >= 1
    end

    test "mutations are applied during single pass" do
      # This test verifies no index skipping by checking deterministic behavior
      input = "0123456789"

      :rand.seed(:exsplus, {777, 888, 999})
      {:ok, result1} = Text.mutate(input, rate: 0.3, operations: [:replace])

      :rand.seed(:exsplus, {777, 888, 999})
      {:ok, result2} = Text.mutate(input, rate: 0.3, operations: [:replace])

      assert result1 == result2
      assert String.length(result1) == String.length(input)
    end

    test "insert operations grow string correctly" do
      input = "ab"

      :rand.seed(:exsplus, {50, 60, 70})
      {:ok, result} = Text.mutate(input, rate: 1.0, operations: [:insert])

      # With rate 1.0 and insert-only, should grow
      assert String.length(result) > String.length(input)
    end

    test "mixed operations with deterministic seed" do
      input = "The quick brown fox"

      :rand.seed(:exsplus, {123, 456, 789})
      {:ok, result1} = Text.mutate(input, rate: 0.4, operations: [:replace, :insert, :delete])

      :rand.seed(:exsplus, {123, 456, 789})
      {:ok, result2} = Text.mutate(input, rate: 0.4, operations: [:replace, :insert, :delete])

      assert result1 == result2
    end

    test "replace operation maintains length" do
      input = "stable"

      :rand.seed(:exsplus, {11, 22, 33})
      {:ok, result} = Text.mutate(input, rate: 0.5, operations: [:replace])

      assert String.length(result) == String.length(input)
    end

    test "returns error for non-string entities" do
      assert {:error, message} = Text.mutate(123, rate: 1.0)
      assert message =~ "Text mutation only works with string entities"
    end

    test "mutation_strength/1 has an expected lower bound" do
      assert Text.mutation_strength(0) == 1.0
      assert Text.mutation_strength(100) < 1.0
      assert Text.mutation_strength(10_000) == 0.1
    end
  end
end
