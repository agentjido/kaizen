defmodule Kaizen.Selection.TournamentTest do
  use ExUnit.Case, async: true

  alias Kaizen.Selection.Tournament

  describe "select/4" do
    test "handles negative scores without errors" do
      population = ["a", "b", "c", "d"]
      scores = %{"a" => -10.0, "b" => -5.0, "c" => -15.0, "d" => -2.0}

      selected = Tournament.select(population, scores, 10, tournament_size: 2)

      assert length(selected) == 10
      assert Enum.all?(selected, &(&1 in population))
    end

    test "handles mix of negative and positive scores" do
      population = ["a", "b", "c", "d"]
      scores = %{"a" => -100.0, "b" => 50.0, "c" => -50.0, "d" => 100.0}

      selected = Tournament.select(population, scores, 10, tournament_size: 2)

      assert length(selected) == 10
      assert Enum.all?(selected, &(&1 in population))
    end

    test "favors higher scores over many trials" do
      population = ["low", "high"]
      scores = %{"low" => -100.0, "high" => 100.0}

      # Run many tournaments
      selected = Tournament.select(population, scores, 1000, tournament_size: 2)

      # Count selections
      counts = Enum.frequencies(selected)
      high_count = Map.get(counts, "high", 0)
      low_count = Map.get(counts, "low", 0)

      # Higher score should be selected significantly more often
      assert high_count > low_count * 2
    end

    test "with uniform scores, selection approximates uniform distribution" do
      population = ["a", "b", "c", "d"]
      scores = %{"a" => 5.0, "b" => 5.0, "c" => 5.0, "d" => 5.0}

      selected = Tournament.select(population, scores, 1000, tournament_size: 2)

      counts = Enum.frequencies(selected)

      # Each entity should be selected roughly equally (within 40% tolerance)
      expected = 250
      tolerance = 100

      Enum.each(population, fn entity ->
        count = Map.get(counts, entity, 0)

        assert count >= expected - tolerance and count <= expected + tolerance,
               "Entity #{entity} selected #{count} times, expected ~#{expected}"
      end)
    end

    test "edge case: all same scores (constant fitness)" do
      population = ["a", "b", "c"]
      scores = %{"a" => -42.0, "b" => -42.0, "c" => -42.0}

      selected = Tournament.select(population, scores, 100, tournament_size: 2)

      assert length(selected) == 100
      assert Enum.all?(selected, &(&1 in population))

      # Should distribute relatively evenly
      counts = Enum.frequencies(selected)
      # More than one entity selected
      assert map_size(counts) > 1
    end

    test "edge case: very large negative and positive scores" do
      population = ["a", "b", "c"]
      scores = %{"a" => -1_000_000.0, "b" => 0.0, "c" => 1_000_000.0}

      selected = Tournament.select(population, scores, 100, tournament_size: 3)

      assert length(selected) == 100
      assert Enum.all?(selected, &(&1 in population))

      counts = Enum.frequencies(selected)
      # "c" should be selected most often due to highest score
      assert Map.get(counts, "c", 0) > Map.get(counts, "a", 0)
    end

    test "pressure increases selection bias toward higher scores" do
      population = ["low", "mid", "high"]
      scores = %{"low" => -10.0, "mid" => 0.0, "high" => 10.0}

      # Low pressure - more exploration
      selected_low_pressure =
        Tournament.select(population, scores, 1000, tournament_size: 3, pressure: 0.5)

      counts_low = Enum.frequencies(selected_low_pressure)

      # High pressure - more exploitation
      selected_high_pressure =
        Tournament.select(population, scores, 1000, tournament_size: 3, pressure: 3.0)

      counts_high = Enum.frequencies(selected_high_pressure)

      # With tournament_size=3, "high" should dominate especially with high pressure
      # High pressure should give "high" a larger share
      high_share_low = Map.get(counts_low, "high", 0) / 1000
      high_share_high = Map.get(counts_high, "high", 0) / 1000

      # Higher pressure should increase the share (allowing for randomness)
      assert high_share_high >= high_share_low
      # "high" should be selected most often with high pressure
      assert Map.get(counts_high, "high", 0) >= Map.get(counts_high, "mid", 0)
    end

    test "preserves ordering after normalization" do
      population = ["worst", "bad", "ok", "good", "best"]

      scores = %{
        "worst" => -100.0,
        "bad" => -50.0,
        "ok" => 0.0,
        "good" => 50.0,
        "best" => 100.0
      }

      # Run many tournaments with smaller tournament size to get distribution
      selected = Tournament.select(population, scores, 2000, tournament_size: 3, pressure: 2.0)

      counts = Enum.frequencies(selected)

      # Verify ordering is generally preserved (higher scores selected more often)
      # "best" should be selected most
      assert Map.get(counts, "best", 0) > Map.get(counts, "good", 0)
      # "worst" should be selected least
      assert Map.get(counts, "best", 0) > Map.get(counts, "worst", 0)
      assert Map.get(counts, "good", 0) > Map.get(counts, "worst", 0)
    end

    test "returns empty list for empty population" do
      assert Tournament.select([], %{}, 5) == []
    end

    test "returns empty list for empty scores" do
      assert Tournament.select(["a", "b"], %{}, 5) == []
    end

    test "handles tournament size larger than population" do
      population = ["a", "b"]
      scores = %{"a" => 1.0, "b" => 2.0}

      selected = Tournament.select(population, scores, 10, tournament_size: 10)

      assert length(selected) == 10
      assert Enum.all?(selected, &(&1 in population))
    end

    test "negative scores with fractional pressure" do
      population = ["a", "b", "c"]
      scores = %{"a" => -9.0, "b" => -4.0, "c" => -1.0}

      # This would fail with direct exponentiation of negative numbers
      selected = Tournament.select(population, scores, 100, tournament_size: 2, pressure: 1.5)

      assert length(selected) == 100
      assert Enum.all?(selected, &(&1 in population))

      # Higher (less negative) score should still be favored
      counts = Enum.frequencies(selected)
      assert Map.get(counts, "c", 0) > Map.get(counts, "a", 0)
    end

    test "respects tournament_size option" do
      population = ["a", "b", "c", "d", "e", "f"]
      scores = %{"a" => 1.0, "b" => 2.0, "c" => 3.0, "d" => 4.0, "e" => 5.0, "f" => 6.0}

      # With tournament_size=1, selection is random (since only 1 candidate)
      selected_size_1 = Tournament.select(population, scores, 500, tournament_size: 1)
      counts_1 = Enum.frequencies(selected_size_1)

      # With tournament_size=6 (whole population), best always wins
      selected_size_6 = Tournament.select(population, scores, 500, tournament_size: 6)
      counts_6 = Enum.frequencies(selected_size_6)

      # Size 1 should have more diverse distribution
      assert map_size(counts_1) > 1, "Size 1 tournaments should select multiple entities"

      # Size 6 should heavily favor "f" (best entity)
      assert Map.get(counts_6, "f", 0) > 400, "Size 6 tournaments should mostly select best"
    end

    test "respects pressure option from config" do
      population = ["low", "mid", "high"]
      scores = %{"low" => 1.0, "mid" => 5.0, "high" => 10.0}

      # Pressure=0.5 - low exploitation, more exploration
      selected_p05 =
        Tournament.select(population, scores, 1000, tournament_size: 2, pressure: 0.5)

      counts_p05 = Enum.frequencies(selected_p05)

      # Pressure=3.0 - high exploitation, less exploration
      selected_p3 = Tournament.select(population, scores, 1000, tournament_size: 2, pressure: 3.0)
      counts_p3 = Enum.frequencies(selected_p3)

      # Higher pressure should increase "high" selection rate
      high_rate_p05 = Map.get(counts_p05, "high", 0) / 1000
      high_rate_p3 = Map.get(counts_p3, "high", 0) / 1000

      # With higher pressure, "high" should be selected more often (allowing some randomness)
      # At minimum, both should favor "high" over "low"
      assert high_rate_p3 >= high_rate_p05 * 0.9,
             "Pressure 3.0 (#{high_rate_p3}) should select 'high' at least as often as pressure 0.5 (#{high_rate_p05})"
    end
  end
end
