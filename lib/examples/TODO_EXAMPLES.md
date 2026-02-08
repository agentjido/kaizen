# Example Implementations TODO

This document outlines planned example implementations demonstrating Kaizen's capabilities across different problem domains and complexity levels.

## 1. String Evolution to Target ✅

**Status**: IMPLEMENTED (see `hello_world.ex`)  
**Complexity**: Beginner  
**Domain**: String matching  

**Description**: Evolve random strings toward "Hello, world!" using character-level mutations.

**Key Concepts**:
- Basic fitness evaluation (Jaro distance)
- Character-level mutation
- Simple selection pressure
- Convergence observation

**Kaizen Components**:
- `Kaizen.Evolvable.String` (built-in)
- `Kaizen.Mutation.Text` (built-in)
- Custom fitness module

---

## 2. Knapsack Problem Optimization

**Status**: IMPLEMENTED (see `knapsack.ex`)  
**Complexity**: Intermediate  
**Domain**: Combinatorial optimization  

**Description**: Select items with weights and values to maximize total value without exceeding weight capacity.

**Key Concepts**:
- Binary genome representation (item included/excluded)
- Constraint handling (weight limit)
- Penalty functions for invalid solutions
- Practical optimization problem

**Implementation Requirements**:
- Custom `Evolvable` implementation for binary vectors
- Fitness with constraint penalties: `value - penalty * max(0, weight - limit)`
- Mutation: bit flips
- Crossover: uniform or single-point

**Example Problem**:
```elixir
items = [
  %{name: "laptop", weight: 3, value: 2000},
  %{name: "camera", weight: 1, value: 1000},
  %{name: "book", weight: 2, value: 100},
  # ... more items
]
capacity = 10
```

**File**: `lib/examples/knapsack.ex`

---

## 3. Neural Network Hyperparameter Tuning

**Status**: IMPLEMENTED (see `hyperparameter_tuning.ex`)  
**Complexity**: Intermediate-Advanced  
**Domain**: Machine learning optimization  

**Description**: Evolve hyperparameters (learning rate, layer sizes, dropout rates, activation functions) to maximize validation accuracy.

**Key Concepts**:
- Configuration/map evolution
- Expensive fitness evaluation (train models)
- Mixed-type parameters (continuous, discrete, categorical)
- Practical ML workflow integration

**Implementation Requirements**:
- Custom `Evolvable` for hyperparameter maps
- Mutation strategies:
  - Continuous: Gaussian perturbation for learning rate, dropout
  - Discrete: ±1 for layer sizes
  - Categorical: random selection for activations
- Fitness: train small model, return validation accuracy
- Consider caching to avoid retraining identical configs

**Example Genome**:
```elixir
%{
  learning_rate: 0.001,
  hidden_layers: [128, 64, 32],
  dropout_rate: 0.2,
  activation: :relu,
  batch_size: 32,
  optimizer: :adam
}
```

**File**: `lib/examples/hyperparameter_tuning.ex`

---

## 4. Traveling Salesman Problem (TSP)

**Status**: IMPLEMENTED (see `traveling_salesman.ex`)  
**Complexity**: Advanced  
**Domain**: Route optimization  

**Description**: Find the shortest route visiting all cities exactly once and returning to the start.

**Key Concepts**:
- Permutation-based genome
- Specialized crossover operators (PMX, OX, CX)
- Specialized mutation operators (swap, inversion, insertion)
- NP-hard problem with practical applications
- Solution validity constraints

**Implementation Requirements**:
- Custom `Evolvable.Permutation` protocol implementation
- Custom crossover strategies:
  - Partially Mapped Crossover (PMX)
  - Order Crossover (OX)
  - Cycle Crossover (CX)
- Custom mutation strategies:
  - Swap mutation (swap two cities)
  - Inversion mutation (reverse segment)
  - Insertion mutation (move city to new position)
- Fitness: total route distance (minimize, so return negative or `1/distance`)
- Distance matrix calculation

**Example Cities**:
```elixir
cities = [
  %{name: "A", x: 0, y: 0},
  %{name: "B", x: 1, y: 3},
  %{name: "C", x: 4, y: 1},
  # ... more cities
]

# Genome is permutation: [0, 3, 1, 4, 2]
```

**File**: `lib/examples/traveling_salesman.ex`

---

## 5. Multi-Objective Antenna Design

**Status**: TODO  
**Complexity**: Expert  
**Domain**: Engineering design optimization  

**Description**: Evolve antenna shape parameters to simultaneously optimize gain, bandwidth, and minimize size. Demonstrates true multi-objective optimization with conflicting goals.

**Key Concepts**:
- Multi-objective fitness (Pareto optimization)
- Continuous parameter spaces
- Conflicting objectives (no single "best" solution)
- Pareto front exploration
- Engineering constraints
- Trade-off analysis

**Implementation Requirements**:
- Custom `Evolvable` for continuous parameter vectors
- Multi-objective fitness returning vector: `{gain, bandwidth, -size}`
- Pareto selection strategy (requires implementation):
  - Non-dominated sorting
  - Crowding distance calculation
  - Diversity preservation
- Constraints:
  - Parameter bounds (physical limits)
  - Validity checking (feasible designs)
- Visualization of Pareto front evolution

**Example Genome**:
```elixir
%{
  length: 0.5,        # meters, 0.1-2.0
  width: 0.2,         # meters, 0.1-1.0
  angle: 45.0,        # degrees, 0-90
  material: :copper,  # :copper | :aluminum | :silver
  frequency: 2.4      # GHz, 0.5-5.0
}
```

**Objectives** (all maximize):
- Gain: `simulate_gain(antenna)` (dBi)
- Bandwidth: `simulate_bandwidth(antenna)` (MHz)
- Compactness: `-calculate_volume(antenna)` (negative volume in m³)

**File**: `lib/examples/multi_objective_antenna.ex`

---

## Implementation Priority

1. ✅ **String Evolution** - Complete
2. ✅ **Knapsack** - Complete; demonstrates constraints and binary genomes
3. ✅ **TSP** - Complete; demonstrates specialized operators (PMX, permutation mutation)
4. ✅ **Hyperparameter Tuning** - Complete; demonstrates schema-driven evolution
5. **Multi-Objective Antenna** - Requires Pareto selection implementation (NSGA-II)

---

## Additional Example Ideas (Future)

### Configuration Optimization
- Evolve server/database configurations for throughput/latency
- Demonstrates real-world DevOps applications

### Game AI Parameter Evolution
- Evolve bot behavior parameters for game AI
- Fitness: win rate against reference opponents

### Symbolic Regression
- Evolve mathematical expressions to fit data
- Demonstrates tree-based genomes and GP

### Image Filter Evolution
- Evolve filter parameters to achieve target visual style
- Demonstrates creative/aesthetic fitness functions

### Schedule Optimization
- Evolve employee schedules, meeting times, resource allocation
- Demonstrates constraint satisfaction problems

---

## Testing Guidelines

Each example should include:
- Doctest examples showing basic usage
- ExUnit tests verifying:
  - Evolution completes without errors
  - Fitness improves over generations
  - Best solution meets minimum quality threshold
- Documentation explaining:
  - Problem domain and objectives
  - Genome representation
  - Fitness calculation
  - Expected results

---

## Documentation Standards

Each example file should follow this structure:

```elixir
defmodule Kaizen.Examples.ProblemName do
  @moduledoc """
  Brief description of the problem.
  
  ## Problem Description
  Detailed explanation...
  
  ## Genome Representation
  How entities are encoded...
  
  ## Fitness Evaluation
  How solutions are scored...
  
  ## Usage
  
      iex> Kaizen.Examples.ProblemName.run()
      # ... expected output
  
  ## Expected Results
  What to expect when running...
  """
  
  # Implementation...
end
```

---

## Notes

- Start simple: Focus on clear, well-documented examples
- Performance secondary to clarity in examples
- Include visualization helpers where appropriate (ASCII charts, data for plotting)
- Consider adding `mix` tasks for easy running: `mix kaizen.example knapsack`
