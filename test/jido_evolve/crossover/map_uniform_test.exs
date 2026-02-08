defmodule Jido.Evolve.Crossover.MapUniformTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Config
  alias Jido.Evolve.Crossover.MapUniform

  describe "crossover/3 with symmetric keys" do
    test "produces valid children with same keys" do
      parent1 = %{lr: 0.01, batch_size: 32, activation: :relu}
      parent2 = %{lr: 0.001, batch_size: 64, activation: :tanh}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert is_map(child1)
      assert is_map(child2)
      assert MapSet.new(Map.keys(child1)) == MapSet.new([:lr, :batch_size, :activation])
      assert MapSet.new(Map.keys(child2)) == MapSet.new([:lr, :batch_size, :activation])
    end

    test "children have values from parents" do
      parent1 = %{lr: 0.01, batch_size: 32}
      parent2 = %{lr: 0.001, batch_size: 64}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      # Values should come from one of the parents
      assert child1.lr in [0.01, 0.001]
      assert child1.batch_size in [32, 64]
      assert child2.lr in [0.01, 0.001]
      assert child2.batch_size in [32, 64]
    end

    test "list crossover performs one-point crossover" do
      parent1 = %{layers: [128, 64, 32]}
      parent2 = %{layers: [256, 128, 64]}

      config = Config.new!()

      # Run multiple times to ensure we get crossover (due to randomness)
      results =
        for _ <- 1..20 do
          {child1, child2} = MapUniform.crossover(parent1, parent2, config)
          {child1.layers, child2.layers}
        end

      # At least some results should show actual crossover
      # (not just copying one parent entirely)
      assert Enum.any?(results, fn {layers, _} ->
               layers != [128, 64, 32] and layers != [256, 128, 64]
             end)
    end
  end

  describe "crossover/3 with asymmetric keys" do
    test "handles parent1 having extra keys" do
      parent1 = %{lr: 0.01, batch_size: 32, dropout: 0.5}
      parent2 = %{lr: 0.001, batch_size: 64}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      # Both children should have all keys from both parents
      assert MapSet.new(Map.keys(child1)) == MapSet.new([:lr, :batch_size, :dropout])
      assert MapSet.new(Map.keys(child2)) == MapSet.new([:lr, :batch_size, :dropout])
    end

    test "handles parent2 having extra keys" do
      parent1 = %{lr: 0.01, batch_size: 32}
      parent2 = %{lr: 0.001, batch_size: 64, activation: :tanh}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      # Both children should have all keys from both parents
      assert MapSet.new(Map.keys(child1)) == MapSet.new([:lr, :batch_size, :activation])
      assert MapSet.new(Map.keys(child2)) == MapSet.new([:lr, :batch_size, :activation])
    end

    test "handles both parents having unique keys" do
      parent1 = %{lr: 0.01, dropout: 0.5, momentum: 0.9}
      parent2 = %{lr: 0.001, batch_size: 64, activation: :relu}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      expected_keys = MapSet.new([:lr, :dropout, :momentum, :batch_size, :activation])
      assert MapSet.new(Map.keys(child1)) == expected_keys
      assert MapSet.new(Map.keys(child2)) == expected_keys
    end

    test "missing keys are handled correctly" do
      parent1 = %{lr: 0.01, dropout: 0.5}
      parent2 = %{lr: 0.001, batch_size: 64}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      # dropout should come from parent1, batch_size from parent2
      # (since the other parent has nil for those keys)
      assert child1.dropout == 0.5
      assert child1.batch_size == 64
      assert child2.dropout == 0.5
      assert child2.batch_size == 64
    end

    test "completely disjoint key sets" do
      parent1 = %{a: 1, b: 2}
      parent2 = %{c: 3, d: 4}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert MapSet.new(Map.keys(child1)) == MapSet.new([:a, :b, :c, :d])
      assert MapSet.new(Map.keys(child2)) == MapSet.new([:a, :b, :c, :d])

      # Values should be preserved from the parent that has them
      assert child1.a == 1
      assert child1.b == 2
      assert child1.c == 3
      assert child1.d == 4
    end
  end

  describe "crossover/3 with empty maps" do
    test "handles one empty parent" do
      parent1 = %{lr: 0.01}
      parent2 = %{}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert MapSet.new(Map.keys(child1)) == MapSet.new([:lr])
      assert MapSet.new(Map.keys(child2)) == MapSet.new([:lr])
      assert child1.lr == 0.01
      assert child2.lr == 0.01
    end

    test "handles both empty parents" do
      parent1 = %{}
      parent2 = %{}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert child1 == %{}
      assert child2 == %{}
    end
  end

  describe "crossover/3 with invalid inputs" do
    test "returns parents unchanged for non-map parent1" do
      parent1 = "not a map"
      parent2 = %{lr: 0.01}

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert child1 == parent1
      assert child2 == parent2
    end

    test "returns parents unchanged for non-map parent2" do
      parent1 = %{lr: 0.01}
      parent2 = "not a map"

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert child1 == parent1
      assert child2 == parent2
    end

    test "returns parents unchanged for both non-maps" do
      parent1 = "not a map"
      parent2 = [1, 2, 3]

      config = Config.new!()
      {child1, child2} = MapUniform.crossover(parent1, parent2, config)

      assert child1 == parent1
      assert child2 == parent2
    end
  end

  describe "crossover/3 with list values" do
    test "handles different length lists" do
      parent1 = %{layers: [128, 64]}
      parent2 = %{layers: [256, 128, 64, 32]}

      config = Config.new!()
      {child1, _child2} = MapUniform.crossover(parent1, parent2, config)

      assert is_list(child1.layers)
      assert length(child1.layers) > 0
    end

    test "handles empty lists" do
      parent1 = %{layers: []}
      parent2 = %{layers: [128, 64]}

      config = Config.new!()
      {child1, _child2} = MapUniform.crossover(parent1, parent2, config)

      # Should select one of the parent lists
      assert child1.layers in [[], [128, 64]]
    end
  end
end
