defmodule Jido.EvolveTest do
  use ExUnit.Case
  doctest Jido.Evolve

  test "greets the world" do
    assert Jido.Evolve.version() != nil
  end
end
