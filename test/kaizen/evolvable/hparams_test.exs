defmodule Kaizen.Evolvable.HParamsTest do
  use ExUnit.Case, async: true

  alias Kaizen.Evolvable.HParams

  describe "new/1 with range and tuple bounds" do
    test "accepts tuple bounds for float linear" do
      schema = %{learning_rate: {:float, {0.001, 0.1}, :linear}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :learning_rate)
      assert hparams.learning_rate >= 0.001
      assert hparams.learning_rate <= 0.1
    end

    test "accepts range bounds for float linear (tuple format preferred)" do
      # Note: Elixir ranges require integers, so float bounds must use tuple format
      schema = %{temperature: {:float, {0.5, 2.0}, :linear}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :temperature)
      assert hparams.temperature >= 0.5
      assert hparams.temperature <= 2.0
    end

    test "accepts tuple bounds for float log" do
      schema = %{learning_rate: {:float, {1.0e-5, 1.0e-1}, :log}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :learning_rate)
      assert hparams.learning_rate >= 1.0e-5
      assert hparams.learning_rate <= 1.0e-1
    end

    test "accepts range bounds for float log (tuple format preferred)" do
      # Note: Elixir ranges require integers, so float bounds must use tuple format
      schema = %{alpha: {:float, {1.0e-5, 1.0e-1}, :log}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :alpha)
      assert hparams.alpha >= 1.0e-5
      assert hparams.alpha <= 1.0e-1
    end

    test "accepts tuple bounds for int" do
      schema = %{batch_size: {:int, {16, 128}}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :batch_size)
      assert hparams.batch_size >= 16
      assert hparams.batch_size <= 128
    end

    test "accepts range bounds for int" do
      schema = %{batch_size: {:int, 16..128}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :batch_size)
      assert hparams.batch_size >= 16
      assert hparams.batch_size <= 128
    end

    test "accepts mixed tuple and range bounds" do
      schema = %{
        learning_rate: {:float, {0.001, 0.1}, :log},
        batch_size: {:int, 16..128},
        dropout: {:float, {0.0, 0.5}, :linear}
      }

      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :learning_rate)
      assert Map.has_key?(hparams, :batch_size)
      assert Map.has_key?(hparams, :dropout)
    end

    test "accepts tuple bounds for list length" do
      schema = %{hidden_layers: {:list, {:int, {16, 256}}, length: {1, 3}}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :hidden_layers)
      assert is_list(hparams.hidden_layers)
      assert length(hparams.hidden_layers) >= 1
      assert length(hparams.hidden_layers) <= 3

      Enum.each(hparams.hidden_layers, fn val ->
        assert val >= 16
        assert val <= 256
      end)
    end

    test "accepts range bounds for int values" do
      schema = %{hidden_layers: {:list, {:int, 16..256}, length: {1, 3}}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :hidden_layers)
      assert is_list(hparams.hidden_layers)
      assert length(hparams.hidden_layers) >= 1
      assert length(hparams.hidden_layers) <= 3

      Enum.each(hparams.hidden_layers, fn val ->
        assert val >= 16
        assert val <= 256
      end)
    end

    test "handles enum type" do
      schema = %{activation: {:enum, [:relu, :tanh, :gelu]}}
      hparams = HParams.new(schema)

      assert is_map(hparams)
      assert Map.has_key?(hparams, :activation)
      assert hparams.activation in [:relu, :tanh, :gelu]
    end
  end

  describe "new/1 validation" do
    test "returns error for non-map schema" do
      assert {:error, "HParams requires a schema map"} = HParams.new("not a map")
      assert {:error, "HParams requires a schema map"} = HParams.new([])
      assert {:error, "HParams requires a schema map"} = HParams.new(nil)
    end
  end

  describe "Evolvable protocol implementation" do
    test "to_genome/1 returns map as-is" do
      map = %{lr: 0.01, batch_size: 32}
      assert Kaizen.Evolvable.to_genome(map) == map
    end

    test "from_genome/2 returns genome as-is" do
      original = %{lr: 0.01}
      genome = %{lr: 0.02}
      assert Kaizen.Evolvable.from_genome(original, genome) == genome
    end

    test "similarity/2 returns 0.0 for identical maps" do
      map1 = %{lr: 0.01, batch_size: 32}
      map2 = %{lr: 0.01, batch_size: 32}
      assert Kaizen.Evolvable.similarity(map1, map2) == 0.0
    end

    test "similarity/2 returns 1.0 for completely different maps" do
      map1 = %{lr: 0.01, batch_size: 32}
      map2 = %{lr: 0.02, batch_size: 64}
      assert Kaizen.Evolvable.similarity(map1, map2) == 1.0
    end

    test "similarity/2 returns 0.5 for half different maps" do
      map1 = %{lr: 0.01, batch_size: 32}
      map2 = %{lr: 0.01, batch_size: 64}
      assert Kaizen.Evolvable.similarity(map1, map2) == 0.5
    end

    test "similarity/2 returns 1.0 for different keys" do
      map1 = %{lr: 0.01}
      map2 = %{batch_size: 32}
      assert Kaizen.Evolvable.similarity(map1, map2) == 1.0
    end
  end
end
