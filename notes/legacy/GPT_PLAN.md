Below is a focused, architecture‑level review and a concrete implementation plan to address correctness, API consistency, extensibility, and performance. I’ve grouped changes by priority; each item lists files to touch, the exact sections to modify, rationale, interface changes, and side‑effects.

---

## Executive summary (what’s good)

* **Clear separation of roles:** Behaviours (`Fitness`, `Selection`, `Mutation`) and protocol (`Evolvable`) give a solid, extensible core.
* **Stream‑driven engine with telemetry and concurrency:** `Jido.Evolve.Engine` uses `Task.async_stream/3` and emits telemetry—good foundations for scaling.
* **Examples demonstrate breadth:** From strings to TSP and HParams, the package showcases multiple genome types and operators.

## High‑impact issues to fix first

1. **Permutation inversion mutation is incorrect for edge indices**
2. **Mutation probability is double‑applied (Engine + Mutation modules)**
3. **Tournament selection can produce invalid math with negative scores**
4. **PMX crossover returns only one “real” child**
5. **Text/Random mutation index drift when inserting/deleting during iteration**
6. **Random seeding uses `:rand.seed(:default, integer)`—make explicit and reproducible**
7. **Docs/schema mismatches in HParams**

---

# Implementation plan

## 1) Fix `Jido.Evolve.Mutation.Permutation.inversion/1` slicing (bug)

**Files:**

* `lib/jido_evolve/mutation/permutation.ex`

**Change:** Replace `Enum.slice/2` range slicing with start+length slicing to avoid negative/descending ranges. Also make the segment inclusive.

**Modify in:** `defp inversion(permutation)`

**Before (problem):**

```elixir
before = Enum.slice(permutation, 0..(start_idx - 1))
segment = Enum.slice(permutation, start_idx..end_idx) |> Enum.reverse()
after_segment = Enum.slice(permutation, (end_idx + 1)..(n - 1))
```

**After (pattern):**

```elixir
before = Enum.slice(permutation, 0, start_idx)
segment = permutation |> Enum.slice(start_idx, end_idx - start_idx + 1) |> Enum.reverse()
after_segment = Enum.slice(permutation, end_idx + 1, n - (end_idx + 1))
```

**Why:** Range slices like `0..-1` produce unintended results. Start/length avoids that.

**Side effects:** None beyond correctness; outputs become valid permutations consistently.

---

## 2) Remove double mutation gating and clarify semantics

**Problem:** `Engine` applies a per‑entity mutation chance *and* mutation modules apply their own probabilities (`:rate`), giving an unintended squared effect (e.g., `0.1 * 0.1 = 1%`). This especially hurts `Binary` where `rate` is per‑gene.

**Approach A (recommended): Engine never gates, modules own probability logic.**

**Files:**

* `lib/jido_evolve/engine.ex` (main)
* (Optional) `lib/jido_evolve/config.ex` (naming clarifications)

**Modify in:** `select_and_breed/7`

**Change:** Call `mutation_module.mutate/2` **unconditionally** for children; pass the configured `:rate`. The module decides whether and how much to mutate.

**Current:**

```elixir
if :rand.uniform() < config.mutation_rate do
  mutation_opts = [rate: config.mutation_rate, strength: ...]
  case mutation_module.mutate(child, mutation_opts) do
    ...
end
```

**Replace with:**

```elixir
mutation_opts = [
  rate: config.mutation_rate,
  strength: mutation_module.mutation_strength(state.generation),
  best_fitness: state.best_score || 0.0
]
case mutation_module.mutate(child, mutation_opts) do
  {:ok, mutated} -> mutated
  {:error, _} -> child
end
```

**Reasoning:** Keeps semantics consistent across mutation strategies; `Binary/Text/HParams` already interpret `:rate` per element/gene; `Permutation` interprets it per operator—still fine as module‑local choice.

**Optional config clarification:** In `Jido.Evolve.Config` docs, document that `mutation_rate` is **interpreted by the selected mutation module** (per‑gene for binary/text, per‑operation for permutation). If you prefer strict separation, introduce **two knobs**:

* `mutation_entity_chance` (Engine gating)
* `mutation_gene_rate` (module per‑gene rate)
  …but that’s a breaking change; the simpler fix above avoids the break.

**Side effects:** Expect more mutations than before (no extra gate). Adjust default `mutation_rate` values if needed.

---

## 3) Make tournament selection robust for negative scores

**Files:**

* `lib/jido_evolve/selection/tournament.ex`
* `lib/jido_evolve/engine.ex` (to pass options, see #4)

**Issue:** `:math.pow(score, pressure)` fails for negative scores when `pressure` is non‑integer and is non‑monotonic around zero.

**Change:** Normalize scores to [0,1] and exponentiate that; or rank‑based weights. Simple normalization keeps semantics:

**Modify in:** `run_tournament/4`

```elixir
# compute once (pass min/max or precompute in select/4)
{min_s, max_s} = Enum.min_max(Map.values(scores))
norm = if max_s == min_s, do: 0.5, else: (score - min_s) / (max_s - min_s)
adjusted_score = :math.pow(norm, pressure)
```

**Side effects:** Preserves ordering while allowing pressure to operate meaningfully on any score domain.

---

## 4) Pass selection options from `Config` into `Selection.select/4`

**Files:**

* `lib/jido_evolve/engine.ex`

**Issue:** Engine calls `selection_module.select(population, scores, count, [])`, ignoring configurable knobs like tournament size.

**Modify in:** `select_and_breed/7`

```elixir
selection_opts = [tournament_size: 2, pressure: 1.0] # derive from config, or add fields
all_parents = selection_module.select(population, scores, offspring_count * 2, selection_opts)
```

**Config update (optional non‑breaking):** Document how to pass selection options (e.g., add `selection_opts` field to `Jido.Evolve.Config`). If you want strong typing, add fields `tournament_size :: pos_integer`, `selection_pressure :: float` to `Config` and use them here.

**Side effects:** Better control over evolutionary pressure; reproducible behavior.

---

## 5) Return **two** children in PMX (current returns one child + parent2)

**Files:**

* `lib/jido_evolve/crossover/pmx.ex`

**Issue:** Current implementation maps only one child. That halves recombination benefits.

**Modify in:** `crossover/3` to build both children:

* Build `child1` from `parent1 ⟵ parent2` (existing logic).
* Build `child2` from `parent2 ⟵ parent1` (swap roles, or reuse mapping inversely).

**Signature unchanged:** `@spec crossover(list, list, map) :: {list, list}`

**Side effects:** Increased diversity; may slightly change convergence speed/quality.

---

## 6) Fix index drift in `Text`/`Random` mutation when inserting/deleting

**Files:**

* `lib/jido_evolve/mutation/text.ex`
* `lib/jido_evolve/mutation/random.ex`

**Issue:** Both iterate with indices from the original list and mutate `acc`, so inserts/deletes shift indices.

**Change:** Replace `Enum.with_index |> reduce` with a single‑pass cursor loop over a dynamic list:

**Pattern to use (illustrative):**

```elixir
defp walk(chars, i, rate, ops) do
  cond do
    i >= length(chars) -> chars
    :rand.uniform() < rate ->
      case Enum.random(ops) do
        :replace -> walk(List.replace_at(chars, i, pick()), i + 1, rate, ops)
        :delete  -> walk(List.delete_at(chars, i), i, rate, ops)
        :insert  -> walk(List.insert_at(chars, i, pick()), i + 1, rate, ops)
      end
    true ->
      walk(chars, i + 1, rate, ops)
  end
end
```

Use this in `apply_mutations/3` for both modules.

**Side effects:** Predictable mutation behavior when insertions/deletions are enabled.

---

## 7) Adjust insertion mutation for permutations

**Files:**

* `lib/jido_evolve/mutation/permutation.ex`

**Issue:** After deleting at `from_idx`, subsequent `to_idx` should be adjusted if `to_idx > from_idx` (the list is shorter by one).

**Modify in:** `defp insertion(permutation)`:

```elixir
value = Enum.at(permutation, from_idx)
without = List.delete_at(permutation, from_idx)
adj_to = if to_idx > from_idx, do: to_idx - 1, else: to_idx
result = List.insert_at(without, adj_to, value)
```

**Side effects:** Stable position semantics; fewer no‑op/odd placements.

---

## 8) Make random seeding explicit and reproducible

**Files:**

* `lib/jido_evolve/config.ex`

**Issue:** `:rand.seed(:default, seed)` with integer is ambiguous across OTP versions.

**Change:** Use a specific algorithm and 3‑tuple:

```elixir
def init_random_seed(%__MODULE__{random_seed: seed}) when is_integer(seed) do
  :rand.seed(:exs1024, {seed, seed <<< 1, seed <<< 2})
  :ok
end
```

(Any deterministic 3‑tuple is fine; bit shifts just vary state.)

**Side effects:** Reproducible runs across Erlang/OTP versions.

---

## 9) Use grapheme‑aware string crossover (optional)

**Files:**

* `lib/jido_evolve/crossover/string.ex`

**Issue:** Current slicing is codepoint‑based. Combining marks/emoji may split incorrectly.

**Change:** Convert to graphemes:

```elixir
g1 = String.graphemes(parent1)
g2 = String.graphemes(parent2)
# choose point in min(length(g1), length(g2))
# then join: Enum.take(g1, point) ++ Enum.drop(g2, point) |> Enum.join()
```

**Side effects:** Correct behavior on user text; slight performance hit. For ASCII targets it’s unchanged.

---

## 10) Normalize options passing to operators and document

**Files:**

* `lib/jido_evolve/config.ex` (docs)
* `lib/jido_evolve/engine.ex` (option pluming, see #4)
* `lib/jido_evolve/selection/tournament.ex` (honor options)

**Change:** Adopt a consistent pattern:

* **Engine** passes `selection_opts`, `mutation_opts` (rate/strength/best_fitness), `crossover_opts` (reserved) from config.
* **Config**: optionally add `selection_opts :: keyword`, `crossover_opts :: keyword`, and document `mutation_rate` semantics (module‑interpreted).

**Side effects:** Clear extension points; minimal code changes.

---

## 11) Crossover for maps: handle asymmetric keys

**Files:**

* `lib/jido_evolve/crossover/map_uniform.ex`

**Issue:** Keys are taken separately for child1/child2. If parents differ in keys, children may differ in shape.

**Change:** Build union of keys and decide per key:

```elixir
keys = Map.keys(parent1) |> MapSet.new() |> MapSet.union(Map.keys(parent2) |> MapSet.new()) |> MapSet.to_list()
child1 = for k <- keys, into: %{}, do: {k, crossover_value(Map.get(parent1, k), Map.get(parent2, k))}
child2 = for k <- keys, into: %{}, do: {k, crossover_value(Map.get(parent2, k), Map.get(parent1, k))}
```

**Side effects:** More robust when schemas drift; if schemas are guaranteed same, this is harmless.

---

## 12) Batch evaluation support in Engine

**Files:**

* `lib/jido_evolve/engine.ex`

**Issue:** Engine ignores `batch_evaluate/2`.

**Change:** In `evaluate_population/3`, detect and use batch:

```elixir
if function_exported?(fitness_module, :batch_evaluate, 2) do
  # split population into chunks of size = config.max_concurrency (or config.batch_size)
  # evaluate per chunk in parallel tasks, then merge into scores map
else
  # current per-entity path
end
```

**Interfaces:** Consider adding `evaluation_batch_size :: pos_integer` to `Config`.

**Side effects:** Big speedup for models that can evaluate batches efficiently.

---

## 13) Tournament diversity maintenance (optional hook)

**Files:**

* `lib/jido_evolve/selection.ex` (docs already have optional callback)
* `lib/jido_evolve/engine.ex`

**Change:** After `select/4`, call `maintain_diversity/3` if exported:

```elixir
selected = selection_module.select(...)
selected = if function_exported?(selection_module, :maintain_diversity, 3),
  do: selection_module.maintain_diversity(population, selected, selection_opts),
  else: selected
```

**Side effects:** Pluggable niching/elitism diversity policies.

---

## 14) Logging API compatibility (`Logger.warning/2` vs `Logger.warn/2`)

**Files:**

* `lib/jido_evolve/engine.ex`

**Issue:** Some Elixir versions prefer `Logger.warn/2`. Pick one and use consistently. If you need cross‑version compatibility, define a small helper:

```elixir
defp warn(msg, meta) do
  if function_exported?(Logger, :warning, 2), do: Logger.warning(msg, meta), else: Logger.warn(msg, meta)
end
```

**Side effects:** Avoids runtime warnings across Elixir versions.

---

## 15) HParams: documentation/schema consistency

**Files:**

* `lib/jido_evolve/evolvable/hparams.ex`
* `lib/examples/hyperparameter_tuning.ex`
* `lib/examples/TODO_EXAMPLES.md`

**Issues:**

* `HParams.new/1` returns a **map**, but docs show `{:ok, map}`.
* Examples show range syntax `a..b` but implementation uses tuples `{a, b}`.

**Changes:**

* Update docs to reflect tuple bounds and direct return (map).
* Optionally **accept both** range and tuple forms for flexibility:

  * Update `random_value/1` and `mutate_value/3` to pattern match on `min..max` **and** `{min, max}`.

**Interfaces:** No breaking changes if you add dual matching.

**Side effects:** Cleaner developer experience; fewer surprises.

---

## 16) Directory and naming hygiene (optional but clarifying)

**Files/Structure:**

* Move `lib/jido_evolve/protocols/crossover.ex` → `lib/jido_evolve/crossover/behaviour.ex` (or keep path but rename module doc)
* The module is a **behaviour**, not a protocol; the name `Jido.Evolve.Crossover` is correct, but the directory path “protocols/” is misleading.

**Side effects:** None at runtime; improves discoverability.

---

## 17) Engine configurability: evaluation timeout and telemetry fields

**Files:**

* `lib/jido_evolve/config.ex`
* `lib/jido_evolve/engine.ex`

**Change:** Add `evaluation_timeout :: pos_integer | :infinity` to config and use it in `Task.async_stream/3` instead of the hardcoded `:timer.seconds(30)`. Include more telemetry fields (mutation_rate, crossover_rate, diversity).

**Side effects:** Better control under heavy fitness functions; richer observability.

---

## 18) Multi‑objective support scaffolding (to unlock `TODO_EXAMPLES.md` item)

**Files (new):**

* `lib/jido_evolve/selection/nsga2.ex` (new selection behaviour implementation)
* `lib/jido_evolve/fitness/multi.ex` (optional helpers for vector fitness and Pareto utilities)

**Interfaces:**

* `Jido.Evolve.Fitness.evaluate/2` to allow returning `{:ok, %{score: score, metadata: %{objectives: [f1, f2, ...]}}}`
* `Jido.Evolve.Selection.NSGA2.select/4` signature per behaviour; internally perform non‑dominated sorting and crowding distance.

**Engine changes:**

* No interface change if `Selection` module encapsulates all logic; Engine selection call remains the same.

**Side effects:** Enables the “Multi‑Objective Antenna Design” example with minimal Engine changes.

---

## 19) Minor polish and consistency

* **Knapsack optimal value comment:** Update comment from `2^10` to `2^15` in `lib/examples/knapsack.ex` (`@items` has 15 items).
* **Distance accumulation in TSP:** OK as is; consider caching last city wrap (already done).
* **Diversity calculation:** Current sampling is fine; if you later want deterministic sampling for reproducibility, seed a local RNG stream or sample fixed pairs per generation based on generation number.

---

# API deltas (summary)

* **No breaking changes** required for the major fixes:

  * Fix inversion (bug), adjust insertion index, make selection robust, PMX yields 2 children, Engine stops gating mutation.
* **Optional config additions (non‑breaking if given defaults):**

  * `evaluation_timeout` (integer or `:infinity`)
  * `selection_opts :: keyword`
  * `crossover_opts :: keyword`
* **Docs/contracts clarified:**

  * `mutation_rate` semantics belong to the mutation module
  * `HParams` accepts `{min, max}` (and optionally `min..max`)

---

# Risks and interactions

* **Increased mutation frequency** after removing Engine gating may change convergence rates; keep defaults conservative (e.g., `0.1–0.3`).
* **Selection normalization** changes deterministic behavior of existing runs—but fixes correctness for negative scores (e.g., TSP).
* **PMX two‑child output** increases diversity; it may require slight retuning of `crossover_rate`.

---

## Concrete signatures/snippets (reference)

* **Engine (unconditional mutation call):**

```elixir
mutation_opts = [rate: config.mutation_rate,
                 strength: mutation_module.mutation_strength(state.generation),
                 best_fitness: state.best_score || 0.0]
child = case mutation_module.mutate(child, mutation_opts) do
  {:ok, mutated} -> mutated
  _ -> child
end
```

* **Tournament normalization:**

```elixir
{min_s, max_s} = Enum.min_max(Map.values(scores))
normalize = fn s ->
  if max_s == min_s, do: 0.5, else: (s - min_s) / (max_s - min_s)
end
adjusted_score = :math.pow(normalize.(score), pressure)
```

* **Seeding:**

```elixir
def init_random_seed(%__MODULE__{random_seed: seed}) when is_integer(seed) do
  :rand.seed(:exs1024, {seed, seed <<< 1, seed <<< 2})
  :ok
end
```

* **Permutation inversion (fixed slicing):**

```elixir
before = Enum.slice(permutation, 0, start_idx)
segment = Enum.slice(permutation, start_idx, end_idx - start_idx + 1) |> Enum.reverse()
after_segment = Enum.slice(permutation, end_idx + 1, n - (end_idx + 1))
{:ok, before ++ segment ++ after_segment}
```

---

## Suggested order of work

1. **Correctness fixes:** Permutation inversion & insertion; Engine mutation gating; Tournament normalization; PMX 2 children; Text/Random index drift.
2. **Config/Engine wiring:** pass selection opts; add evaluation timeout; improve seeding.
3. **MapUniform key union; grapheme‑aware crossover (if needed).**
4. **Docs/HParams schema corrections.**
5. **(Optional) NSGA‑II selection.**

---

If you want, I can prepare a small patch set for each change (as diffs) or sketch the `NSGA2` selection skeleton next.
