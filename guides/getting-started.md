# Getting Started

Jido.Evolve provides a simple public API for evolutionary search.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:jido_evolve, "~> 0.2.0"}
  ]
end
```

## Optional Igniter Install

```bash
mix igniter.install jido_evolve
```

## Basic Usage

```elixir
defmodule MyFitness do
  use Jido.Evolve.Fitness

  def evaluate(entity, _ctx), do: {:ok, String.length(entity)}
end

stream =
  Jido.Evolve.evolve(
    initial_population: ["a", "abcd", "abc"],
    fitness: MyFitness
  )

final_state = Enum.reduce(stream, fn _state, acc -> acc end)
IO.inspect(final_state.best_entity)
```
