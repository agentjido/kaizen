# Generic Evolutionary Algorithm Design in Elixir

## Core Philosophy

Design a composable, protocol-based evolutionary system that can evolve any data structure (text, maps, JSON, code, etc.) using pluggable strategies for mutation, crossover, selection, and evaluation.

## 1. Core Protocols & Behaviours

### 1.1 Evolvable Protocol
```elixir
defprotocol Kaizen.Evolvable do
  @doc "Convert to a normalized representation for evolution"
  def to_genome(entity)
  
  @doc "Convert from genome back to entity type"
  def from_genome(genome, original_entity)
  
  @doc "Calculate similarity between two entities"
  def similarity(entity1, entity2)
end

# Example implementations:
# - Text: genome is list of words/chars
# - Map: genome is flattened key-value pairs
# - JSON: genome is path-value pairs
# - Code: genome is AST nodes
```

### 1.2 Fitness Behaviour
```elixir
defmodule Kaizen.Fitness do
  @callback evaluate(entity :: any(), context :: map()) :: 
    {:ok, float()} | {:ok, %{score: float(), metadata: map()}}
  
  @callback batch_evaluate(entities :: list(), context :: map()) :: 
    {:ok, list({entity_id, score})}
    
  @callback compare(entity1 :: any(), entity2 :: any(), context :: map()) ::
    :better | :worse | :equal
end
```

### 1.3 Mutation Behaviour
```elixir
defmodule Evolutionary.Mutation do
  @callback mutate(entity :: any(), opts :: keyword()) :: 
    {:ok, mutated_entity} | {:error, reason}
  
  @callback mutate_with_feedback(
    entity :: any(), 
    feedback :: map(), 
    opts :: keyword()
  ) :: {:ok, mutated_entity}
  
  @callback mutation_strength(generation :: integer()) :: float()
end
```

### 1.4 Selection Behaviour
```elixir
defmodule Evolutionary.Selection do
  @callback select(
    population :: list(),
    scores :: map(),
    count :: integer(),
    opts :: keyword()
  ) :: list()
  
  @optional_callbacks [maintain_diversity: 3]
  @callback maintain_diversity(
    population :: list(),
    selected :: list(),
    opts :: keyword()
  ) :: list()
end
```

## 2. Core Engine Architecture

### 2.1 Population Manager (GenServer)
```elixir
defmodule Evolutionary.Population do
  @moduledoc """
  Manages the evolving population with history tracking
  """
  
  defstruct [
    :id,
    :population,      # Current population
    :scores,          # Map of entity_id => score
    :generation,      # Current generation number
    :history,         # List of previous generations
    :metadata,        # Additional tracking data
    :config           # Evolution configuration
  ]
  
  # Key functions:
  # - add_entity/2
  # - remove_entity/2
  # - get_best/2 (by different criteria)
  # - get_diverse_sample/2
  # - checkpoint/1
  # - restore/2
end
```

### 2.2 Evolution Supervisor Tree
```elixir
Evolutionary.Supervisor
├── Evolutionary.Engine (Main coordinator)
├── Evolutionary.Population (State management)
├── Evolutionary.Evaluator.Supervisor
│   └── Task.Supervisor (Parallel evaluation)
├── Evolutionary.Mutator.Pool (Mutation workers)
└── Evolutionary.Metrics (Telemetry & tracking)
```

### 2.3 Main Engine
```elixir
defmodule Evolutionary.Engine do
  @moduledoc """
  Orchestrates the evolutionary process
  """
  
  def evolve(initial_population, config) do
    # Returns a Stream for lazy evaluation
    Stream.unfold(initial_state, &evolution_step/1)
    |> Stream.take_while(&continue_evolving?/1)
  end
  
  defp evolution_step(state) do
    state
    |> evaluate_population()
    |> select_parents()
    |> generate_offspring()
    |> apply_elitism()
    |> update_metrics()
    |> checkpoint_if_needed()
  end
end
```

## 3. Strategy Implementations

### 3.1 Selection Strategies
```elixir
defmodule Evolutionary.Selection.Tournament do
  @behaviour Evolutionary.Selection
  # Tournament selection with configurable tournament size
end

defmodule Evolutionary.Selection.Pareto do
  @behaviour Evolutionary.Selection
  # Multi-objective Pareto frontier selection
  # Key for GEPA-like systems
end

defmodule Evolutionary.Selection.Roulette do
  @behaviour Evolutionary.Selection
  # Fitness-proportionate selection
end

defmodule Evolutionary.Selection.Rank do
  @behaviour Evolutionary.Selection
  # Rank-based selection to avoid fitness scaling issues
end
```

### 3.2 Mutation Strategies
```elixir
defmodule Evolutionary.Mutation.Random do
  # Pure random mutations
end

defmodule Evolutionary.Mutation.Guided do
  # Mutations guided by feedback/gradients
end

defmodule Evolutionary.Mutation.LLM do
  # LLM-based intelligent mutations (for GEPA)
  # Uses ReqLLM to propose mutations
end

defmodule Evolutionary.Mutation.Adaptive do
  # Adjusts mutation rate based on progress
end
```

### 3.3 Crossover Strategies
```elixir
defmodule Evolutionary.Crossover.SinglePoint do
  # Traditional single-point crossover
end

defmodule Evolutionary.Crossover.Uniform do
  # Uniform crossover with configurable probability
end

defmodule Evolutionary.Crossover.Semantic do
  # Semantic-aware crossover (for structured data)
end

defmodule Evolutionary.Crossover.LLM do
  # LLM-based intelligent merging
end
```

## 4. Multi-Objective Optimization

### 4.1 Pareto Frontier Management
```elixir
defmodule Evolutionary.Pareto do
  @moduledoc """
  Manages Pareto-optimal solutions for multi-objective problems
  """
  
  defstruct [
    :frontier,        # Set of non-dominated solutions
    :objectives,      # List of objective functions
    :dominance_map,   # Who dominates whom
    :coverage_map     # Task coverage per solution
  ]
  
  def update_frontier(pareto, new_solution, scores)
  def get_dominated_by(pareto, solution)
  def sample_by_coverage(pareto)
  def merge_frontiers(pareto1, pareto2)
end
```

### 4.2 Objective Functions
```elixir
defmodule Evolutionary.Objectives do
  @moduledoc """
  Common objective functions and combinators
  """
  
  def maximize(metric_fn)
  def minimize(metric_fn)
  def target_value(metric_fn, target)
  def weighted_sum(objectives, weights)
  def lexicographic(objectives)
end
```

## 5. Feedback Integration

### 5.1 Feedback Protocol
```elixir
defprotocol Evolutionary.Feedback do
  @doc "Extract actionable feedback from evaluation results"
  def extract_feedback(evaluation_result)
  
  @doc "Incorporate feedback into mutation strategy"
  def apply_feedback(entity, feedback, strategy)
end
```

### 5.2 Learning from History
```elixir
defmodule Evolutionary.Learning do
  @moduledoc """
  Learns patterns from evolution history
  """
  
  def identify_successful_patterns(history)
  def identify_failure_patterns(history)
  def suggest_strategy_adjustments(patterns)
  def update_mutation_distribution(patterns)
end
```

## 6. Parallel Execution

### 6.1 Parallel Evaluator
```elixir
defmodule Evolutionary.Evaluator do
  @moduledoc """
  Manages parallel evaluation with rate limiting
  """
  
  def evaluate_batch(entities, fitness_module, opts \\ []) do
    opts = Keyword.merge([
      max_concurrency: System.schedulers_online(),
      timeout: :timer.seconds(30),
      ordered: false
    ], opts)
    
    Task.Supervisor.async_stream_nolink(
      Evolutionary.TaskSupervisor,
      entities,
      fitness_module,
      :evaluate,
      opts
    )
    |> handle_results()
  end
end
```

### 6.2 Distributed Evolution (Optional)
```elixir
defmodule Evolutionary.Distributed do
  @moduledoc """
  Distributes evolution across multiple nodes
  """
  
  def partition_population(population, nodes)
  def migrate_individuals(node1, node2, count)
  def synchronize_frontiers(nodes)
  def aggregate_results(partial_results)
end
```

## 7. Configuration DSL

### 7.1 Configuration Schema
```elixir
defmodule Evolutionary.Config do
  use Ecto.Schema
  
  embedded_schema do
    field :population_size, :integer, default: 100
    field :generations, :integer, default: 1000
    field :mutation_rate, :float, default: 0.1
    field :crossover_rate, :float, default: 0.7
    field :elitism_rate, :float, default: 0.05
    field :selection_strategy, :string, default: "tournament"
    field :termination_criteria, :map
    field :checkpoint_interval, :integer
    field :metrics_enabled, :boolean, default: true
  end
end
```

### 7.2 Builder DSL
```elixir
defmodule Evolutionary.DSL do
  @moduledoc """
  Provides a nice DSL for configuring evolution
  """
  
  defmacro evolution(name, do: block) do
    quote do
      config = unquote(block)
      Evolutionary.Registry.register(unquote(name), config)
    end
  end
  
  def population(size: size), do: {:population_size, size}
  def select(strategy), do: {:selection, strategy}
  def mutate(rate: rate), do: {:mutation_rate, rate}
  def crossover(rate: rate), do: {:crossover_rate, rate}
  def terminate(when: criteria), do: {:termination, criteria}
end

# Usage:
evolution :text_optimizer do
  population size: 100
  select :pareto
  mutate rate: 0.2
  crossover rate: 0.6
  terminate when: [
    generations: 1000,
    no_improvement: 50,
    target_fitness: 0.95
  ]
end
```

## 8. Observability

### 8.1 Telemetry Events
```elixir
defmodule Evolutionary.Telemetry do
  @events [
    [:evolutionary, :generation, :start],
    [:evolutionary, :generation, :stop],
    [:evolutionary, :evaluation, :start],
    [:evolutionary, :evaluation, :stop],
    [:evolutionary, :mutation, :success],
    [:evolutionary, :mutation, :failure],
    [:evolutionary, :selection, :complete],
    [:evolutionary, :frontier, :updated]
  ]
  
  def setup do
    # Attach default handlers
    # Can integrate with LiveDashboard
  end
end
```

### 8.2 Metrics Collector
```elixir
defmodule Evolutionary.Metrics do
  @moduledoc """
  Collects and aggregates evolution metrics
  """
  
  defstruct [
    :best_fitness_history,
    :average_fitness_history,
    :diversity_history,
    :mutation_success_rate,
    :convergence_velocity,
    :pareto_frontier_size
  ]
  
  def track_generation(metrics, generation_data)
  def export_csv(metrics, path)
  def plot_convergence(metrics)
end
```

## 9. Usage Examples

### 9.1 Text Evolution
```elixir
defmodule MyApp.TextEvolution do
  def optimize_prompt(seed_text, target_behavior) do
    config = %Evolutionary.Config{
      population_size: 50,
      selection_strategy: "tournament",
      mutation_rate: 0.3
    }
    
    Evolutionary.evolve(
      initial: [seed_text],
      fitness: &evaluate_prompt(&1, target_behavior),
      mutation: Evolutionary.Mutation.LLM,
      config: config
    )
    |> Enum.take(100)
    |> List.last()
    |> Map.get(:best)
  end
end
```

### 9.2 JSON Structure Evolution
```elixir
defmodule MyApp.JSONEvolution do
  def optimize_config(initial_json, performance_metric) do
    Evolutionary.evolve(
      initial: [initial_json],
      fitness: performance_metric,
      mutation: Evolutionary.Mutation.Semantic,
      crossover: Evolutionary.Crossover.Semantic,
      selection: Evolutionary.Selection.Pareto,
      objectives: [:latency, :accuracy, :cost]
    )
    |> Stream.take_while(fn state -> 
      state.generation < 500
    end)
    |> Enum.to_list()
    |> extract_pareto_frontier()
  end
end
```

### 9.3 GEPA-style Implementation
```elixir
defmodule MyApp.GEPA do
  def optimize_prompts(seed_prompts, tasks) do
    Evolutionary.evolve(
      initial: seed_prompts,
      fitness: &LLMEvaluator.evaluate(&1, tasks),
      mutation: &LLMReflection.mutate_with_feedback/2,
      selection: Evolutionary.Selection.Pareto,
      config: %{
        use_reflection: true,
        maintain_frontier: true,
        exploration_rate: 0.2
      }
    )
  end
end
```

## 10. Extension Points

### 10.1 Custom Evolvable Types
```elixir
defimpl Evolutionary.Evolvable, for: MyCustomType do
  def to_genome(entity), do: # ...
  def from_genome(genome, _original), do: # ...
  def similarity(e1, e2), do: # ...
end
```

### 10.2 Custom Fitness Functions
```elixir
defmodule MyFitness do
  @behaviour Evolutionary.Fitness
  
  def evaluate(entity, context) do
    # Complex evaluation logic
    # Can call external services, LLMs, etc.
  end
end
```

### 10.3 Hooks and Callbacks
```elixir
defmodule Evolutionary.Hooks do
  @callback before_generation(state :: map()) :: :ok
  @callback after_generation(state :: map()) :: :ok
  @callback on_new_best(entity :: any(), score :: float()) :: :ok
  @callback on_convergence(state :: map()) :: :ok
end
```

## Design Principles

1. **Protocol-based** - Extensible for any data type
2. **Behaviour-driven** - Pluggable strategies
3. **Stream-based** - Lazy evaluation, composable
4. **Concurrent** - Leverages Elixir's strengths
5. **Observable** - Built-in telemetry and metrics
6. **Fault-tolerant** - Supervised processes, checkpointing
7. **Composable** - Mix and match strategies
8. **Testable** - Each component in isolation

## Key Advantages

- **Generic** - Works with any data structure
- **Specialized** - Easy to create domain-specific variants
- **Performant** - Parallel evaluation, lazy streams
- **Maintainable** - Clear separation of concerns
- **Extensible** - New strategies without modifying core
- **Production-ready** - Telemetry, metrics, fault tolerance