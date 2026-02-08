# Kaizen Library Overview

## What It Does

Kaizen is a generic, extensible evolutionary algorithm (EA) framework for Elixir. It evolves entities (strings, configurations, maps, etc.) toward higher fitness using pluggable strategies for evaluation, selection, mutation, and crossover.

**Use Cases:**
- Text/prompt evolution (optimize strings toward target metrics)
- Configuration/parameter tuning (server settings, hyperparameters)
- Structure optimization (JSON payloads, API schemas)
- Any domain where "generate → score → iterate on better candidates" applies

See `lib/examples/hello_world.ex` for a runnable example.

## How It Works

### Architecture

**Stream-based engine**: Call `Kaizen.evolve/1` to receive a lazy `Stream` of `Kaizen.State` snapshots (one per generation).

**Pluggable strategies**: Fitness, Selection, Mutation, and Crossover are behaviors; `Evolvable` is a protocol for representation and similarity.

**Parallel scoring**: Fitness evaluations run concurrently via `Task.async_stream` with configurable `max_concurrency`.

**Observability**: Emits telemetry events for evolution, generations, and evaluations.

### Generation Flow

1. **Evaluate** population fitness (parallel)
2. **Select** parents using selection strategy
3. **Breed** next generation:
   - Crossover pairs with probability `crossover_rate`
   - Mutate offspring with probability `mutation_rate`
4. **Apply elitism** (preserve best entities)
5. **Advance** generation with updated scores, diversity, and history
6. **Check termination** criteria (target fitness, max generations, etc.)

### Core Modules

**Kaizen.Engine** - Orchestrates the evolutionary loop and returns a `Stream` of states

**Kaizen.State** - Immutable snapshot per generation containing:
- `population`, `scores`, `best_entity`, `best_score`
- `average_score`, `diversity`, `fitness_history`
- `metadata`, `config`

**Kaizen.Config** - Validated configuration with defaults:
- Population size, generations, mutation/crossover/elitism rates
- Selection, mutation, crossover strategy modules
- Termination criteria, concurrency limits, random seed

**Protocols & Behaviors**:
- `Kaizen.Evolvable` (protocol): `to_genome/1`, `from_genome/2`, `similarity/2`
  - Built-in: `Kaizen.Evolvable.String`
- `Kaizen.Fitness` (behavior): `evaluate/2` (required), `batch_evaluate/2`, `compare/3` (optional)
- `Kaizen.Mutation` (behavior): `mutate/2` (required), `mutate_with_feedback/3`, `mutation_strength/1` (optional)
  - Built-in: `Kaizen.Mutation.Text`, `Kaizen.Mutation.Random`
- `Kaizen.Selection` (behavior): `select/4` (required), `maintain_diversity/3` (optional)
  - Built-in: `Kaizen.Selection.Tournament`
- `Kaizen.Crossover` (behavior): `crossover/3`
  - Built-in: `Kaizen.Crossover.String`

### Key Design Decisions

**Protocol-driven extensibility** - Domain-specific strategies plug in without changing the engine

**Lazy evaluation** - Stream-based orchestration allows consumers to control execution

**Concurrency by default** - Bounded parallel fitness evaluation with failure resilience

**Strong validation** - NimbleOptions validates config; TypedStructs clarify contracts

**Diversity tracking** - Computed using `Evolvable.similarity/2` to monitor population convergence

## Quick Start

```elixir
# Define fitness
defmodule MyFitness do
  use Kaizen.Fitness
  def evaluate(entity, _ctx), do: {:ok, score(entity)}
end

# Configure and evolve
config = Kaizen.Config.new!(
  population_size: 50,
  generations: 100,
  mutation_rate: 0.1,
  crossover_rate: 0.7
)

initial_population = ["random", "strings", "here"]

Kaizen.evolve(
  initial_population: initial_population,
  config: config,
  fitness: MyFitness,
  evolvable: Kaizen.Evolvable.String
)
|> Enum.take(100)
|> List.last()
|> then(fn state -> state.best_entity end)
```

## Extending Kaizen

**Custom Fitness**:
```elixir
defmodule MyFitness do
  use Kaizen.Fitness
  def evaluate(entity, ctx), do: {:ok, my_score(entity, ctx)}
end
```

**Custom Mutation**:
```elixir
defmodule MyMutator do
  @behaviour Kaizen.Mutation
  def mutate(entity, opts), do: {:ok, mutated_entity}
end
```

**Custom Evolvable**:
```elixir
defimpl Kaizen.Evolvable, for: MyType do
  def to_genome(t), do: normalize(t)
  def from_genome(_t, genome), do: denormalize(genome)
  def similarity(a, b), do: distance_metric(a, b)
end
```

## Design Documents

- **IDEA.md** - Advanced features (multi-objective, distributed evolution)
- **GEPA.md** - Guidance for LLM/prompt evolution with feedback
- **NEW_API.md** - Proposed higher-level convenience API

## Key Files to Explore

- `lib/kaizen/engine.ex` - Main orchestration loop
- `lib/kaizen/state.ex` - Generation state structure
- `lib/kaizen/config.ex` - Configuration and defaults
- `lib/kaizen/evolvable.ex` - Representation protocol
- `lib/examples/hello_world.ex` - End-to-end usage example
