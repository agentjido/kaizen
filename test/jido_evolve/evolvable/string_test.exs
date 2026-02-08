defmodule Jido.Evolve.Evolvable.StringTest do
  use ExUnit.Case

  test "converts string to genome" do
    genome = Jido.Evolve.Evolvable.to_genome("hello")
    assert genome == ~c"hello"
  end

  test "converts genome back to string" do
    result = Jido.Evolve.Evolvable.from_genome("original", ~c"world")
    assert result == "world"
  end

  test "calculates similarity between identical strings" do
    similarity = Jido.Evolve.Evolvable.similarity("hello", "hello")
    assert similarity == 0.0
  end

  test "calculates similarity between different strings" do
    similarity = Jido.Evolve.Evolvable.similarity("hello", "world")
    assert similarity > 0.0
    assert similarity <= 1.0
  end

  test "calculates similarity between similar strings" do
    similarity = Jido.Evolve.Evolvable.similarity("hello", "hallo")
    assert similarity > 0.0
    assert similarity < 1.0
  end
end
