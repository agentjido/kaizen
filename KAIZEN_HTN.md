# Evolving Hierarchical Task Networks with Kaizen

## Overview

This document explores using the Kaizen evolutionary algorithm framework to evolve HTN planning domains (represented as Elixir structs). The approach leverages Kaizen's pluggable Fitness, Mutation, Selection, Crossover, and Evolvable protocol to search the space of HTN structures while measuring planning outcomes in simulation.

## Goals

- Define fitness signals for HTNs that correlate with useful plans
- Provide HTN-specific mutation and crossover operators
- Support automated and human-in-the-loop evaluation modes
- Use Kaizen's architecture for clean, maintainable implementation

## Scope

- HTN domains exist as Elixir structs (e.g., `Jido.HTN.Domain`)
- Planners and simulators are available/assumed
- Focus on evolving the domain (task methods, decompositions, preconditions), not the planner itself

---

## Representation and Integration with Kaizen

### Entity Representation

- **Entity type**: `Jido.HTN.Domain` (or your domain struct)
- **Genome**: Use the struct directly; no encoding needed
- **Evolvable**: Identity-map to/from genome

### Evolvable Implementation

```elixir
defimpl Kaizen.Evolvable, for: Jido.HTN.Domain do
  def to_genome(domain), do: domain
  
  def from_genome(_domain, genome), do: genome
  
  def similarity(a, b) do
    # Jaccard similarity over method signatures
    sigs = fn d -> 
      MapSet.new(for m <- d.methods, do: {m.task, length(m.subtasks)}) 
    end
    
    as = sigs.(a)
    bs = sigs.(b)
    inter = MapSet.size(MapSet.intersection(as, bs))
    union = MapSet.size(MapSet.union(as, bs))
    
    if union == 0, do: 0.0, else: inter / union
  end
end
```

**Similarity Options**:
- Jaccard similarity over method signatures (set overlap)
- Weighted method edit distance (compare precondition ASTs, child task sequences)
- Simple baseline: signature overlap + structure size ratio

---

## Fitness Evaluation

### Objectives

1. **Plan success rate**: Fraction of problems solved within resource limits
2. **Efficiency**: Average plan cost/length/runtime for solved instances
3. **Generality/robustness**: Success across task distributions, seeds, state perturbations
4. **Readability/complexity**: Penalize bloat (method count, max depth, branching factor)
5. **Validity/consistency**: Penalize cyclic decompositions, unreachable methods, contradictory effects

### Automated Fitness (Scalar Score)

**Formula**:
```
score = w1*success_rate + w2*robustness - w3*normalized_cost - w4*complexity_penalty - w5*violations
```

**Default weights**: `w1=5, w2=2, w3=1, w4=1, w5=3`

**Components**:
- Normalize each component to [0,1] by dividing by a cap
- Choose small integer weights initially and tune

### Fitness Module

```elixir
defmodule KaizenHTN.Fitness do
  use Kaizen.Fitness
  
  @timeout 200  # ms per problem

  def evaluate(domain, ctx) do
    problems = ctx[:problems] || []
    {ok, stats} = run_suite(domain, problems, ctx)
    score = score_from_stats(stats, ctx)
    {:ok, score}
  rescue
    _ -> {:ok, -1.0}  # harsh penalty for crashing/invalid domains
  end

  defp run_suite(domain, problems, ctx) do
    max_conc = ctx[:max_concurrency] || System.schedulers_online()
    
    results =
      Task.async_stream(
        problems, 
        fn p -> eval_one(domain, p, ctx) end,
        max_concurrency: max_conc,
        timeout: @timeout + 50,
        on_timeout: :kill_task
      )
      |> Enum.map(&unwrap/1)
      
    {:ok, summarize(results)}
  end

  defp eval_one(domain, problem, ctx) do
    with {:ok, domain} <- validate_and_repair(domain),
         {:ok, plan, cost} <- planner_run(domain, problem, ctx) do
      %{ok: true, cost: cost, len: length(plan)}
    else
      _ -> %{ok: false}
    end
  end
  
  defp score_from_stats(%{n: n, ok: ok, costs: costs, lens: lens, violations: v}, ctx) do
    s = ok / max(n, 1)
    c = if ok > 0, do: Enum.sum(costs) / ok, else: ctx[:cost_cap] || 50
    l = if ok > 0, do: Enum.sum(lens) / ok, else: ctx[:len_cap] || 50
    k = complexity_penalty(ctx.domain)
    
    w = ctx[:weights] || %{
      success: 5.0, 
      robustness: 2.0, 
      cost: 1.0, 
      complexity: 1.0, 
      violations: 3.0
    }
    
    w.success * s + w.robustness * s - w.cost * normalize(c) - 
      w.complexity * k - w.violations * v
  end
end
```

### Caching and Timeouts

- **Cache evaluations** by hash: `:erlang.phash2(domain)` combined with problem ID and seed
- Store in ETS for the generation
- **Per-problem timeouts** and total evaluation budget
- Treat timeouts as failures with cost cap
- **Parallel evaluation** via `Task.async_stream` with bounded `max_concurrency`

### Dataset Discipline

- **Train/val/test splits**: Compute fitness on train set, monitor validation success
- **K-fold cross-validation** for small suites (rotate folds per generation bucket)
- **Hold-out tasks** to prevent overfitting to benchmarks

---

## Automated Fitness (Multi-objective, Optional)

Return a map with components:
```elixir
%{success: s, cost: c, complexity: k, robustness: r}
```

Implement `compare/3` for Pareto dominance or lexicographic ordering:

```elixir
def compare(_ctx, a, b) do
  dom_a = dominates?(a, b)
  dom_b = dominates?(b, a)
  
  cond do
    dom_a and not dom_b -> :gt
    dom_b and not dom_a -> :lt
    true -> lex([:success, :robustness, :cost, :complexity], a, b)
  end
end
```

---

## Human-in-the-Loop (Optional)

### When to Use

- Automated metrics plateau
- Need to capture subjective quality (readability, maintainability, safety)
- Stakeholders can invest periodic review time (10-15 min per 10 generations)

### Integration Strategies

**1. Pairwise Preference**
- Every N generations, collect top-K diverse candidates
- Ask human to choose better domain per example
- Log pairs (A > B)
- Integrate via:
  - `mutate_with_feedback/3` to bias mutations toward preferred structures
  - Fitness wrapper: `score + λ * preference_score(domain)` from Bradley-Terry model

**2. Rubric Annotation**
- Rate readability/maintainability on scales
- Flag forbidden constructs
- Convert to penalties

**3. Constraint Infusion**
- Accept hard constraints: "must include method for task T with guard G"
- Enforce during validation/repair

### Mechanics

```elixir
# Every N generations:
# 1. Sample top-10 diverse candidates (max-min diversity among top 20%)
# 2. Present pairwise or rubric UI
# 3. Update preference model and fitness shaping term
# 4. Update mutation operator priors (discourage rejected patterns)
```

---

## HTN-Specific Mutation Operators

### Structural Operators

1. **AddMethod(task T)**: Create new method for T with simple decomposition
2. **RemoveMethod(task T)**: Delete random method for T (if >1 exists)
3. **DuplicateMethod(task T)**: Clone method and mutate preconditions/ordering
4. **RewireDecomposition(method M)**: Replace/reorder subset of `M.subtasks`
5. **ReplaceSubtask(M, i, T')**: Swap i-th subtask with compatible task

### Semantic Operators

1. **TweakPrecondition(M, expr)**: Apply small AST edits (change thresholds, add/remove literals, flip booleans)
2. **TweakEffect(primitive op)**: Add/remove effect literal, adjust continuous deltas
3. **RebindResource/Parameters**: Change variable binding or parameter constraints

### Control-Flow Operators

1. **Reorder(M)**: Permute subtasks while respecting ordering constraints
2. **IntroduceGuardedBranch(M)**: Split M into two methods with complementary guards
3. **MergeSimilarMethods(T)**: Merge similar methods (high similarity) by union of guards

### Validation and Repair

After each mutation:
1. Check acyclicity of task decomposition graph
2. Ensure each non-primitive task has ≥1 method
3. Remove unreachable methods conservatively
4. Normalize: sort literal order, canonicalize variable names, remove duplicate subtasks

If validation fails and cannot be repaired in N steps:
- Return `{:discard, domain}` 
- Let Kaizen keep parent or inject random valid repair

### Mutation Strength and Scheduling

```elixir
def mutation_strength(generation) do
  # Anneal: high early (add/remove/rewire), low late (micro-edits)
  max(0.1, 1.0 - generation / max_generations * 0.7)
end
```

Map strength [0,1] to operator distributions.

---

## Crossover Operators

### Method-Set Swap (Homologous)

For shared task names across parents A, B:
- Choose subset of tasks S
- Child inherits A's methods for S and B's methods for others
- Resolve duplicates by similarity tie-break or random

Ensures syntactic validity by keeping well-formed method sets per task.

### Subtree Exchange

- Pick task T
- Replace all methods reachable from T in A with those from B
- Validate and repair

### Uniform Method Union (Conservative)

- Child gets union of method pools for each task (with cap)
- Prune via validation and complexity budget

---

## Selection and Diversity

- Use `Kaizen.Selection.Tournament` with modest pressure (k=3-5)
- Maintain diversity using `Evolvable.similarity/2`
- Optionally reject crosses between near-identical parents
- **Novelty bonus**: Add `+ε*(1 - avg_similarity_to_population)` to discourage collapse

---

## Use Cases and Examples

### Robotics/Manipulation

Evolve domains for pick-place tasks:
- **Success**: Plan found
- **Cost**: Steps or energy
- **Robustness**: Success over varied object poses

### Game AI

NPC behavior trees as HTNs:
- Evolve decomposition strategies for patrol/engage/flee
- Robust behavior across map seeds

### Workflow Automation

DevOps runbooks as HTNs:
- Evolve incident response decompositions
- Minimize steps while satisfying prerequisites

### Toy Example: Blocks World

- **Problems**: Stacks of blocks with random initial configurations
- **Fitness**: Success rate across 20 seeds; cost = steps
- **Complexity penalty**: Method count > M, depth > D
- **Start**: Hand-authored seed domain; mutate to discover efficient variants

---

## Implementation Patterns in Kaizen

### Config and Orchestration

```elixir
config = Kaizen.Config.new!(
  population_size: 40,
  generations: 80,
  mutation_rate: 0.3,
  crossover_rate: 0.6,
  elitism_rate: 0.05,
  selection: Kaizen.Selection.Tournament,
  fitness: KaizenHTN.Fitness,
  mutation: KaizenHTN.Mutation,
  crossover: KaizenHTN.Crossover,
  evolvable: Kaizen.Evolvable.JidoHTN
)

initial_population = seed_domains()  # one hand-authored + random variants

Kaizen.evolve(
  initial_population: initial_population,
  config: config,
  fitness: KaizenHTN.Fitness,
  evolvable: Kaizen.Evolvable.JidoHTN
)
|> Stream.take(80)
|> Enum.to_list()
```

### Fitness Behavior

- Implement `evaluate/2` with per-problem timeout
- ETS cache keyed by `{hash(domain), problem_id}`
- Summarize across train set
- Optionally implement `batch_evaluate/2` to reuse planner setup

### Mutation Behavior

- `mutate/2` chooses operator by distribution + strength
- `validate_and_repair/1` after mutation
- `mutate_with_feedback/3` (optional) biases operators using human signals

### Crossover Behavior

- `crossover/3` implements method-set swap + repair

---

## Trade-offs and Challenges

| Challenge | Mitigation Strategy |
|-----------|---------------------|
| **Credit assignment**: Which methods caused success? | Track which methods used in successful plans; reward broader method coverage |
| **Evaluation cost**: Planning is expensive | Caching, timeouts, subsample problems early, ramp up later |
| **Bloat**: Domains grow unbounded | Complexity penalties, pruning mutations, merge-similar pass |
| **Validity brittleness**: Mutations break invariants | Robust validators and conservative repair |
| **Overfitting**: Too specific to benchmarks | Hold-out validation, domain-shift tests, cross-validation |

---

## Effort and Roadmap

### Milestones

| Size | Time | Task |
|------|------|------|
| M | 1-3d | Fitness.HTNPlanner with benchmark suite, caching, timeouts, telemetry |
| M | 1-3d | Mutation.HTN with validation/repair, core operators, mutation_strength |
| S | ≤1d | Crossover.HTN (method-set swap) + repair |
| S | ≤1d | Evolvable.JidoHTN with similarity; first end-to-end run |
| M | 1-3d | Evaluation discipline (train/val/test), logging, elite archiving |
| M | 1-3d | *Optional*: Human-in-the-loop preference model + UI/CLI |
| M | 1-3d | *Optional*: Multi-objective compare/3 and reporting |

### Signals to Revisit Design

- Fitness saturates early despite operator variety
- Significant runtime per generation (>minutes) with little improvement
- Stakeholder emphasis shifts to readability/safety constraints

---

## Appendix: Minimal Stubs

### Validator/Repair

```elixir
def validate_and_repair(domain) do
  case Validator.run(domain) do
    :ok -> {:ok, domain}
    {:error, issues} -> Repair.apply(domain, issues)
  end
end
```

### Planner Wrapper

```elixir
def planner_run(domain, problem, ctx) do
  timeout = ctx[:per_problem_timeout] || 200
  # Call jido_htn with timeout
  # Return {:ok, plan, cost} | {:error, :timeout} | {:error, reason}
end
```

### Complexity Penalty

```elixir
def complexity_penalty(domain) do
  # e.g., α*methods + β*max_depth + γ*avg_literals
  method_count = length(domain.methods)
  max_depth = compute_max_depth(domain)
  avg_literals = compute_avg_precondition_literals(domain)
  
  0.1 * method_count + 0.05 * max_depth + 0.02 * avg_literals
end
```

---

## Summary

**Start simple**: Automated scalar fitness over a small, curated benchmark with strict validation and interpretable mutation operators.

**Add complexity only when needed**: Multi-objective fitness and human feedback if automated signal fails or progress stalls.

**Key insight**: HTN evolution is feasible with Kaizen's protocol-driven architecture. The main challenge is defining good fitness signals—which can be fully automated through simulation-based planning metrics, requiring no human involvement to start.

**Human involvement becomes valuable** when optimizing for subjective qualities (readability, maintainability, safety) or when automated metrics plateau despite high diversity.
