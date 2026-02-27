# KAIZEN Agent: Multi-Agent LLM-Assisted Evolution

## Overview

Jido.Evolve's architecture naturally supports **multiple LLM "actors"** (judges, critics, refiners, adversaries) providing complementary perspectives during evolution. Each actor is a uniquely prompted LLM call with a specific role, enabling:

- **Multi-perspective fitness evaluation** - Different actors score candidates from different viewpoints
- **Ensemble feedback for mutation** - Structured improvement suggestions from multiple specialized actors
- **Attribution tracking** - Monitor which actors contribute to successful evolution
- **Optional multi-objective selection** - Pareto optimization across actor objectives

This approach extends GEPA's single-reflector pattern to an **actor ensemble** with parallel evaluation, feedback aggregation, and contribution tracking.

## Core Concept

**Actor**: A uniquely prompted LLM call with a defined role (e.g., Safety Judge, Accuracy Critic, Cost Auditor, Refiner, Red-Team Adversary)

**Ensemble**: A set of actors executed in parallel for each candidate entity

**Aggregation**: Combine actor scores into fitness for selection; merge actor feedback for guided mutation

**Attribution**: Track which actors' suggestions are applied and correlate with fitness improvements

## How Jido.Evolve Supports Multi-Agent Evolution

Jido.Evolve's pluggable architecture requires **no core changes**:

**Fitness behavior** - Wrap multiple actor evaluations, aggregate to scalar fitness, store per-actor scores/feedback in metadata

**Mutation behavior** - Use `mutate_with_feedback/3` to consume structured, multi-actor feedback and apply guided mutations

**Selection behavior** - Use scalar fitness with Tournament selection (simple path) or Pareto selection over objective vectors (advanced path)

**Evolvable protocol** - Unchanged; works with any entity type

**State metadata** - Store per-generation ensemble stats, actor objectives, and attribution logs

## Architecture Patterns

### 1. Actor Definition

```elixir
defmodule Jido.Evolve.Agent.Actor do
  @enforce_keys [:id, :role, :model, :prompt_fn]
  defstruct [
    :id,           # :accuracy, :safety, :cost, :refiner, :adversary
    :role,         # Human-readable description
    :model,        # "openai:gpt-4o-mini", "anthropic:claude-3-haiku"
    :prompt_fn,    # fn(entity, ctx) -> {system, user} | prompt_text
    :parse_fn,     # fn(raw) -> %{score: float | nil, feedback: list(), confidence: 0..1}
    weight: 1.0,   # For score aggregation
    kind: :judge   # :judge | :refiner | :adversary
  ]
end
```

### 2. Ensemble Orchestrator

```elixir
defmodule Jido.Evolve.Agent.Ensemble do
  @default_max_concurrency System.schedulers_online()

  def evaluate_and_feedback(entity, ctx) do
    actors = Map.fetch!(ctx, :actors)
    max_concurrency = Map.get(ctx, :actor_max_concurrency, @default_max_concurrency)

    actors
    |> Task.async_stream(
      fn actor -> call_actor(actor, entity, ctx) end,
      max_concurrency: max_concurrency,
      ordered: false,
      timeout: Map.get(ctx, :timeout, :timer.seconds(60))
    )
    |> Enum.reduce(%{scores: %{}, feedback: %{}, raw: %{}}, &accumulate/2)
  end

  defp call_actor(%Jido.Evolve.Agent.Actor{} = actor, entity, ctx) do
    {system, user} = actor.prompt_fn.(entity, ctx)
    {:ok, raw} = call_llm(actor.model, [system, user], temperature: 0.1)
    parsed = actor.parse_fn.(raw)
    %{actor: actor.id, raw: raw, parsed: parsed}
  end

  defp accumulate({:ok, %{actor: id, parsed: parsed, raw: raw}}, acc) do
    acc
    |> put_in([:scores, id], Map.get(parsed, :score))
    |> put_in([:feedback, id], Map.get(parsed, :feedback, []))
    |> put_in([:raw, id], raw)
  end
  defp accumulate(_err, acc), do: acc
end
```

### 3. Actor Role Examples

**Accuracy Judge**:
```elixir
%Actor{
  id: :accuracy,
  role: "Accuracy Judge",
  model: "openai:gpt-4o-mini",
  prompt_fn: fn entity, ctx ->
    system = "You are an accuracy judge. Evaluate correctness vs. expected output."
    user = """
    PROMPT:
    #{entity.text}

    TASK INPUT:
    #{ctx.task_input}

    Return JSON: {"score": 0.0-1.0, "reasons": [...], "errors": [...]}
    """
    {system, user}
  end,
  parse_fn: &parse_json_score/1,
  weight: 2.0
}
```

**Safety Judge**:
```elixir
%Actor{
  id: :safety,
  role: "Safety & Compliance Judge",
  model: "anthropic:claude-3-haiku",
  prompt_fn: fn entity, _ctx ->
    {"You are a safety judge. Rate compliance and identify violations.",
     "Evaluate: #{entity.text}\n\nReturn JSON: {\"score\": 0.0-1.0, \"violations\": [...]}"}
  end,
  parse_fn: &parse_json_score/1,
  weight: 1.5
}
```

**Refiner (Suggestions)**:
```elixir
%Actor{
  id: :refiner,
  role: "Improvement Refiner",
  model: "openai:gpt-4o-mini",
  prompt_fn: fn entity, ctx ->
    system = "Suggest specific improvements to enhance accuracy and clarity."
    user = """
    PROMPT:
    #{entity.text}

    CONTEXT:
    #{ctx.task_description}

    Return JSON: {"suggestions": [{"op": "add"|"remove"|"replace", "target": "...", 
                   "content": "...", "rationale": "...", "confidence": 0.0-1.0}]}
    """
    {system, user}
  end,
  parse_fn: &parse_json_suggestions/1,
  weight: 0.0  # No direct score; suggestions only
}
```

**Adversary (Red Team)**:
```elixir
%Actor{
  id: :adversary,
  role: "Red Team Adversary",
  model: "openai:gpt-4o",
  prompt_fn: fn entity, _ctx ->
    {"Find failure modes, prompt injection risks, and edge cases.",
     "Attack prompt: #{entity.text}\n\nReturn JSON: {\"issues\": [...], \"score\": 1.0 - risk_level}"}
  end,
  parse_fn: &parse_json_score/1,
  weight: 1.0
}
```

### 4. Multi-Actor Fitness

```elixir
defmodule Jido.Evolve.PromptEvolution.MultiActorFitness do
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(entity, ctx) do
    result = Jido.Evolve.Agent.Ensemble.evaluate_and_feedback(entity, ctx)
    
    weights = ctx.actors |> Map.new(&{&1.id, &1.weight})

    {sum, weight_sum} =
      result.scores
      |> Enum.reduce({0.0, 0.0}, fn {id, score}, {s, w} ->
        case score do
          score when is_number(score) ->
            weight_i = Map.get(weights, id, 1.0)
            {s + weight_i * score, w + weight_i}
          _ -> 
            {s, w}
        end
      end)

    scalar_fitness = if weight_sum == 0.0, do: 0.0, else: sum / weight_sum

    {:ok, scalar_fitness,
     metadata: %{
       actor_objectives: result.scores,
       actor_feedback: result.feedback,
       actor_raw: result.raw
     }}
  end
end
```

### 5. Feedback Aggregation

```elixir
defmodule Jido.Evolve.Agent.FeedbackAggregator do
  def consolidate(actor_feedback_map, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)
    
    actor_feedback_map
    |> Map.values()
    |> List.flatten()
    |> Enum.group_by(fn %{op: op, target: t} -> {op, t} end)
    |> Enum.map(fn {_key, group} ->
      avg_confidence = 
        group
        |> Enum.map(&(&1.confidence || 0.5))
        |> Enum.sum()
        |> Kernel./(length(group))
      
      %{
        op: hd(group).op,
        target: hd(group).target,
        content: merge_content(group),
        rationale: Enum.map(group, & &1.rationale),
        actors: Enum.map(group, & &1.actor_id),
        confidence: avg_confidence
      }
    end)
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(top_k)
  end

  defp merge_content(group) do
    group 
    |> Enum.map(& &1.content) 
    |> Enum.uniq() 
    |> Enum.join("\n")
  end
end
```

### 6. Multi-Actor Mutation

```elixir
defmodule Jido.Evolve.PromptEvolution.MultiActorMutator do
  @behaviour Jido.Evolve.Mutation

  @impl true
  def mutate(entity, opts), do: mutate_with_feedback(entity, %{}, opts)

  @impl true
  def mutate_with_feedback(entity, feedback, opts) do
    consolidated =
      feedback
      |> Map.get(:actor_feedback, %{})
      |> Jido.Evolve.Agent.FeedbackAggregator.consolidate(top_k: Keyword.get(opts, :top_k, 5))

    new_text =
      Enum.reduce(consolidated, entity.text, fn suggestion, acc ->
        apply_suggestion(acc, suggestion)
      end)

    updated_metadata =
      Map.update(entity.metadata, :mutations, [], fn mutations ->
        [%{
          type: :multi_actor,
          suggestions: consolidated,
          timestamp: DateTime.utc_now()
        } | mutations]
      end)

    {:ok, %{entity | text: new_text, metadata: updated_metadata}}
  end

  defp apply_suggestion(text, %{op: :add, content: content, target: :end}),
    do: text <> "\n" <> content
    
  defp apply_suggestion(text, %{op: :remove, content: pattern}),
    do: String.replace(text, pattern, "")
    
  defp apply_suggestion(text, %{op: :replace, target: old, content: new}),
    do: String.replace(text, old, new)
    
  defp apply_suggestion(text, _), do: text
end
```

### 7. Attribution Tracking

```elixir
defmodule Jido.Evolve.Agent.Attribution do
  def credit(entity, previous_score, new_score) do
    delta = max(new_score - previous_score, 0.0)
    
    last_mutation = List.first(entity.metadata[:mutations] || [])
    actors = 
      (last_mutation[:suggestions] || [])
      |> Enum.flat_map(&(&1.actors || []))
      |> Enum.uniq()

    credit_per_actor = delta / max(length(actors), 1)

    Enum.reduce(actors, entity, fn actor_id, ent ->
      update_in(
        ent.metadata[:contributors][actor_id],
        fn contributor ->
          (contributor || %{applied: 0, credit: 0.0})
          |> Map.update(:applied, 1, &(&1 + 1))
          |> Map.update(:credit, credit_per_actor, &(&1 + credit_per_actor))
          |> Map.put(:last_applied_gen, entity.metadata[:generation])
        end
      )
    end)
  end
end
```

## End-to-End Example

```elixir
# Define actor ensemble
actors = [
  %Jido.Evolve.Agent.Actor{
    id: :accuracy,
    role: "Accuracy Judge",
    model: "openai:gpt-4o-mini",
    prompt_fn: &MyPrompts.accuracy_judge/2,
    parse_fn: &MyParsers.json_score/1,
    weight: 2.0,
    kind: :judge
  },
  %Jido.Evolve.Agent.Actor{
    id: :safety,
    role: "Safety Judge",
    model: "anthropic:claude-3-haiku",
    prompt_fn: &MyPrompts.safety_judge/2,
    parse_fn: &MyParsers.json_score/1,
    weight: 1.5,
    kind: :judge
  },
  %Jido.Evolve.Agent.Actor{
    id: :refiner,
    role: "Improvement Refiner",
    model: "openai:gpt-4o-mini",
    prompt_fn: &MyPrompts.refiner/2,
    parse_fn: &MyParsers.json_suggestions/1,
    weight: 0.0,
    kind: :refiner
  }
]

# Configure evolution
config = Jido.Evolve.Config.new!(
  population_size: 30,
  generations: 40,
  mutation_rate: 0.3,
  crossover_rate: 0.5,
  elitism_rate: 0.1,
  selection_strategy: Jido.Evolve.Selection.Tournament
)

# Evolution context with actors
ctx = %{
  actors: actors,
  actor_max_concurrency: 3,
  task_input: "User asks: What is the capital of France?",
  task_description: "Answer factual questions accurately"
}

# Run evolution
initial_population = generate_initial_prompts(10)

results =
  Jido.Evolve.evolve(
    initial_population: initial_population,
    config: config,
    fitness: Jido.Evolve.PromptEvolution.MultiActorFitness,
    evolvable: Jido.Evolve.Evolvable.String,
    mutation: Jido.Evolve.PromptEvolution.MultiActorMutator,
    context: ctx
  )
  |> Enum.take(40)

best = List.last(results).best_entity

IO.inspect(best.text, label: "Best Prompt")
IO.inspect(best.metadata.contributors, label: "Actor Contributions")
```

## Comparison to GEPA

| Aspect | GEPA | Multi-Agent Jido.Evolve |
|--------|------|-------------------|
| **Actors** | Single reflector LLM | Multiple specialized actors (judges, refiners, adversaries) |
| **Evaluation** | Single feedback stream | Parallel ensemble evaluation |
| **Fitness** | Single metric | Weighted aggregate or multi-objective |
| **Feedback** | One source | Consolidated from multiple actors |
| **Selection** | Standard | Standard or Pareto across objectives |
| **Attribution** | N/A | Per-actor contribution tracking |
| **Use Case** | Simple prompt evolution | Complex multi-criteria optimization |

**Migration Path**: Lift GEPA's reflector as a `:refiner` actor and incrementally add judges.

## Implementation Scope

**Simple (1-3 hours)**:
- Actor struct and ensemble runner
- MultiActorFitness with weighted aggregation
- Adapt existing mutator to read aggregated feedback
- Basic attribution tracking

**Medium (1-2 days)**:
- Robust feedback aggregator with conflict resolution
- LLM response caching
- Telemetry and observability
- Optional Pareto selection

## Best Practices

**Parallelism**: Engine parallelizes entities; ensemble parallelizes actors per entity. Use bounded concurrency at both levels.

**Caching**: Cache actor responses keyed by `{actor_id, entity_hash, task_hash}` to control costs.

**Determinism**: 
- Use low temperature (0.0-0.2) for judges and critics
- Pin actor prompt versions
- Set random seed for reproducibility

**Cost Control**:
- Limit `actor_max_concurrency`
- Cache aggressively
- Use smaller models for initial generations
- Budget token usage per generation

**Prompt Engineering**:
- Normalize output format (JSON with score, feedback, confidence)
- Provide clear evaluation criteria
- Include examples in system prompts
- Version and track prompts for reproducibility

## Advanced Extensions

**Pareto Multi-Objective Selection**:
```elixir
defmodule Jido.Evolve.Selection.Pareto do
  use Jido.Evolve.Selection

  @impl true
  def select(population, _scores, count, opts) do
    objective_vectors = 
      population
      |> Enum.map(&extract_objectives/1)
    
    front = compute_pareto_front(population, objective_vectors)
    
    front
    |> diversify_selection(count)
  end
  
  defp extract_objectives(entity),
    do: entity.metadata.actor_objectives |> Map.values()
end
```

**Dynamic Actor Weighting**:
```elixir
defmodule Jido.Evolve.Agent.DynamicWeighting do
  def adjust_weights(actors, generation_results) do
    Enum.map(actors, fn actor ->
      credit = calculate_credit(actor.id, generation_results)
      new_weight = actor.weight * (1.0 + credit / 10.0)
      %{actor | weight: new_weight}
    end)
  end
end
```

**Hierarchical Evaluation** (cost optimization):
```elixir
# Fast actors first, expensive actors only for top candidates
def evaluate_hierarchical(entity, ctx) do
  quick_result = run_actors(ctx.quick_actors, entity, ctx)
  
  if quick_result.score > ctx.threshold do
    expensive_result = run_actors(ctx.expensive_actors, entity, ctx)
    merge_results(quick_result, expensive_result)
  else
    quick_result
  end
end
```

## When to Use Advanced Patterns

- **Pareto Selection**: When actor objectives genuinely conflict (safety vs. performance, cost vs. accuracy)
- **Dynamic Weighting**: When you need adaptive actor importance based on task performance
- **Hierarchical Evaluation**: When cost/latency requires early filtering
- **Adversarial Loop**: When robustness to edge cases is critical

## Observability

Track via telemetry or metadata:
- Per-actor score distributions over generations
- Actor agreement/disagreement metrics
- Attribution credits per actor
- Feedback application rates
- Cost per generation (tokens, API calls)

```elixir
defmodule MyTelemetry do
  def handle_event([:jido_evolve, :generation, :stop], measurements, metadata, _config) do
    actor_stats = 
      metadata.state.population
      |> Enum.flat_map(&(&1.metadata.actor_objectives || []))
      |> compute_stats()
    
    Logger.info("Generation #{metadata.generation}: #{inspect(actor_stats)}")
  end
end
```

## Summary

Jido.Evolve's pluggable architecture enables sophisticated multi-agent LLM evolution **without core changes**. By wrapping actor ensembles in Fitness modules, consolidating feedback for Mutation, and optionally using Pareto Selection, you can leverage multiple specialized LLMs to evolve prompts, configurations, or any evolvable entity across multiple objectives with full attribution and observability.
