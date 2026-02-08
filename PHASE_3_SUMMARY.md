# Phase 3: Remove Double Mutation Gating - Completion Summary

## Overview
Fixed critical bug where mutation probability was applied twice (once in Engine, once in mutation modules), causing unintended squared effect.

## Changes Made

### 1. Engine.ex - Removed Conditional Gating
**File**: `lib/kaizen/engine.ex`

**Before** (lines 254-272):
```elixir
if :rand.uniform() < config.mutation_rate do
  mutation_opts = [...]
  case mutation_module.mutate(child, mutation_opts) do
    {:ok, mutated} -> mutated
    {:error, reason} -> 
      Logger.warning("Mutation failed", error: reason)
      child
  end
else
  child
end
```

**After** (lines 253-268):
```elixir
# Call mutate unconditionally - module owns probability logic
mutation_opts = [
  rate: config.mutation_rate,
  strength: mutation_module.mutation_strength(state.generation),
  best_fitness: state.best_score || 0.0
]

case mutation_module.mutate(child, mutation_opts) do
  {:ok, mutated} -> mutated
  {:error, reason} ->
    Logger.warning("Mutation failed", error: reason)
    child
end
```

**Impact**: 
- Engine now calls `mutate/2` unconditionally for all children
- Same fix applied to both paired children (line 253) and single parent edge case (line 274)
- Mutation modules control their own probability logic using the `:rate` option

### 2. Config.ex - Updated Documentation
**File**: `lib/kaizen/config.ex`

**Before** (line 45):
```elixir
doc: "Probability of mutation for each entity"
```

**After** (lines 44-50):
```elixir
doc: """
Mutation rate passed to the mutation module (interpretation varies by module).
For Binary/Text/HParams mutations: per-gene probability.
For Permutation mutations: per-operation probability.
The mutation module controls its own probability logic using this value.
"""
```

**Impact**: 
- Clarifies that mutation_rate is **interpreted by the mutation module**
- Documents different semantics for different mutation strategies
- Notes this is a semantic change from previous behavior

### 3. Test Updates
**File**: `test/support/test_helper.exs`

Updated `TestMutation` module to respect the `:rate` option:
- Added probability check: `if :rand.uniform() < rate do`
- Returns entity unchanged when mutation doesn't occur
- Matches behavior of real mutation modules (Binary, Text, etc.)

**File**: `test/engine_test.exs`

Added new test to verify unconditional calling:
- `"mutation module is called unconditionally, owns probability logic"`
- Uses tracking module to verify `mutate/2` is called for all offspring
- Confirms `:rate` option is passed correctly

## Behavioral Changes

### Before (Double Gating)
- Engine: `if rand() < 0.1` → 10% chance to call mutate
- Module: `if rand() < 0.1` → 10% chance to actually mutate
- **Effective rate**: 0.1 × 0.1 = **1%** (squared!)

### After (Single Gating)
- Engine: Always calls mutate
- Module: `if rand() < 0.1` → 10% chance to mutate
- **Effective rate**: **10%** (correct!)

## Impact on Existing Mutation Modules

All existing mutation modules already implement their own probability logic:
- `Kaizen.Mutation.Binary` - per-bit probability
- `Kaizen.Mutation.Text` - per-character probability  
- `Kaizen.Mutation.HParams` - per-hyperparameter probability
- `Kaizen.Mutation.Permutation` - per-operation probability

These modules will now behave correctly without the extra gating layer.

## Test Results

```
mix test
Running ExUnit with seed: 979241, max_cases: 20
..............................................................................
Finished in 0.5 seconds (0.5s async, 0.04s sync)
142 tests, 0 failures
```

All tests pass with no warnings or errors.

## Verification

- ✅ Engine calls `mutate/2` unconditionally
- ✅ Mutation modules control probability via `:rate` option
- ✅ Documentation clarified on mutation_rate semantics
- ✅ All tests updated and passing
- ✅ `mix test` passes (142 tests, 0 failures)
- ✅ `mix compile --warnings-as-errors` passes
- ✅ `mix format` passes
- ✅ No diagnostics errors

## Migration Notes

**For users**: Default `mutation_rate` values (0.1-0.3) remain conservative and appropriate. You will see **more mutations** than before because the bug has been fixed. If you were compensating for the bug with higher rates, you may want to reduce them.

**For custom mutation modules**: Ensure your mutation module implements probability logic that respects the `:rate` option passed in `mutate/2`. This is the standard pattern used by all built-in mutation strategies.

## Success Criteria Met

All success criteria from GPT_PLAN.md have been achieved:
- [x] Engine calls mutation_module.mutate/2 unconditionally
- [x] Mutation modules control their own probability logic via :rate option
- [x] Documentation clarifies mutation_rate semantics
- [x] All tests pass with updated expectations
- [x] `mix test` and quality checks pass
