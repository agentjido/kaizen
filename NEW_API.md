# Jido.Evolve v2 – A Friendlier API for Everyday Developers

## 1. Philosophy & Design Principles  

1. Hide the science, surface the value  
   • Most users only care about "give me a better X". All EA jargon is optional.  
2. Sensible defaults, gradual disclosure of power  
   • One-line "quick solve" → configurable options → full protocol access.  
3. Speak the user's language  
   • *target*, *tweak*, *score* instead of *genome*, *mutation*, *fitness*.  
4. Batteries-included examples  
   • Real-world "recipes" ship with the library and are runnable with `mix run`.  
5. Keep the current engine intact  
   • The new API is a thin convenience layer; power users still use `Jido.Evolve.*` modules directly.

---

## 2. API Walk-through – Before vs. After

### Old (today)

```elixir
defmodule MyFitness do
  use Jido.Evolve.Fitness
  def evaluate(text, _), do: {:ok, String.jaro_distance(text, "Hello")}
end

config = Jido.Evolve.Config.new!(population_size: 100)
Jido.Evolve.evolve(
  initial_population: ["Hxllo"],
  config:   config,
  fitness:  MyFitness,
  evolvable: Jido.Evolve.Evolvable.String
)
|> Enum.take(100) |> List.last()
```

### New (proposed)

```elixir
Jido.Evolve.quick_solve("Hxllo",
  target:  "Hello",
  generations: 100,
  show_progress: true)
#=> "Hello"
```

Under the hood it builds the same config, evolvable, etc.—but the user never sees them.

---

## 3. The New Public Surface

```elixir
# 3.1 One-liner helpers
Jido.Evolve.quick_solve(value, opts \\ [])
Jido.Evolve.tune(fn params -> score end, ranges, opts \\ [])
Jido.Evolve.search_best(fn candidate -> score end, seed, opts \\ [])

# 3.2 Problem objects (mid-level)
Jido.Evolve.Problem.new(initial, scorer, opts \\ [])
Jido.Evolve.Problem.run(problem)

# 3.3 Opt-in power knobs
problem
|> Jido.Evolve.Problem.with_tweak_strategy(:guided)
|> Jido.Evolve.Problem.with_population(200)
|> Jido.Evolve.Problem.run()
```

### Key option names

• :target – a desired value to move toward  
• :generations, :population – numbers most people understand  
• :tweak_rate – % chance we change something each generation  
• :show_progress – pretty console output  
• :stop_when – `fn best -> boolean end` custom termination  

All defaults are loaded from `Jido.Evolve.Defaults`.

---

## 4. Built-in Optimization Scenarios

Module                     | Purpose                           | Real-World Use Case
---------------------------|-----------------------------------|--------------------------------------
Jido.Evolve.StringTarget        | evolve a string to a target text  | Generate test data, password cracking
Jido.Evolve.ServerConfig        | optimize server performance       | Web server tuning, database settings  
Jido.Evolve.QueryOptimizer      | find efficient query patterns     | Database performance, API optimization
Jido.Evolve.UILayout            | evolve better interface layouts   | A/B testing automation, design optimization
Jido.Evolve.ParamsHyperTune     | hyperparameter search             | ML model tuning, algorithm configuration
Jido.Evolve.CacheStrategy       | optimize caching algorithms       | Redis tuning, CDN configuration
Jido.Evolve.Math.Maximize       | maximize mathematical functions   | Engineering optimization, profit maximization

Each scenario is a thin wrapper around `Jido.Evolve.Problem` pre-filled with:
• a default representation (Evolvable)  
• a tweaker (Mutation)  
• a scorer (Fitness)  
• sensible termination rules  

---

## 5. Migration Path (Progressive Complexity)

Step 0 – I just want a better value  
```elixir
Jido.Evolve.quick_solve(start, target: wanted)
```

Step 1 – Custom scoring, still easy  
```elixir
Jido.Evolve.search_best(seed_value,
  score: &my_fun/1,
  generations: 50)
```

Step 2 – Need control over population & tweaks  
```elixir
problem =
  Jido.Evolve.Problem.new(seed_value, &my_fun/1)
  |> Jido.Evolve.Problem.with_population(300)
  |> Jido.Evolve.Problem.with_tweak_rate(0.2)

Jido.Evolve.Problem.run(problem)
```

Step 3 – Power user (today's API)  
```elixir
Jido.Evolve.Engine.evolve(initial, config, fitness, evolvable)
```

Each layer simply builds the next one—zero duplication.

---

## 6. Concrete Code Examples

### 6.1 Web Server Performance Tuning

Automatically find the optimal configuration for your web server:

```elixir
# Define parameter ranges to explore
ranges = %{
  pool_size:      10..200,
  timeout_ms:     100..5000,
  max_connections: 50..1000,
  cache_ttl:      60..3600
}

# Define how to measure "good" performance
scorer = fn %{pool_size: p, timeout_ms: t, max_connections: m, cache_ttl: c} ->
  # Start server with these settings, run load test, return score
  MyApp.LoadTest.run_benchmark(pool_size: p, timeout: t, max_conn: m, cache: c)
  # Returns higher-is-better score (e.g. requests/sec - average_latency)
end

# Let Jido.Evolve find the best settings
best_config = Jido.Evolve.tune(scorer, ranges, 
  generations: 30,
  population: 50,
  show_progress: true
)

IO.puts "🚀 Best server config: #{inspect(best_config)}"
```

### 6.2 API Response Optimization

Evolve the perfect API response structure:

```elixir
# Start with a bloated API response
bloated_response = %{
  user: %{id: 123, name: "Alice", email: "alice@example.com", created_at: "...", 
          preferences: %{theme: "dark", notifications: true}, 
          metadata: %{last_login: "...", ip: "...", user_agent: "..."}},
  permissions: ["read", "write", "admin"],
  session: %{token: "...", expires: "..."},
  debug_info: %{query_time: 0.5, db_hits: 3}
}

# Define what makes a response "good" (smaller size, but keeps essential data)
fitness_fn = fn response ->
  size_penalty = byte_size(:erlang.term_to_binary(response)) / 1000.0
  completeness_score = MyApp.ResponseValidator.score_completeness(response)
  completeness_score - size_penalty  # higher is better
end

# Evolve towards optimal response
optimal = Jido.Evolve.search_best(bloated_response, 
  score: fitness_fn,
  generations: 50,
  tweak_rate: 0.2
)
```

### 6.3 Database Query Optimization

Let evolution discover efficient query patterns:

```elixir
# Start with a slow query structure
initial_query = %{
  select: [:id, :name, :email, :created_at, :updated_at, :metadata],
  joins: [:profile, :preferences, :sessions], 
  where: [status: "active"],
  limit: 1000,
  order_by: :created_at
}

# Measure query performance
query_scorer = fn query_config ->
  {duration, _result} = :timer.tc(fn -> 
    MyApp.Database.execute_query(query_config) 
  end)
  
  # Return inverse of duration (faster = higher score)
  1_000_000 / (duration + 1)  # microseconds to score
end

# Evolve faster queries
fast_query = Jido.Evolve.search_best(initial_query,
  score: query_scorer,
  generations: 25,
  population: 30
)

IO.puts "⚡ Optimized query: #{inspect(fast_query)}"
```

### 6.4 Hyperparameter Tuning (Machine Learning)

```elixir
ranges = %{
  lr:        1.0e-5..1.0e-1,
  batch:     8..128,
  momentum:  0.0..0.99
}

best =
  Jido.Evolve.tune(
    fn %{lr: lr, batch: b, momentum: m} ->
      Model.train_and_score(lr, b, m)    # returns higher-is-better float
    end,
    ranges,
    generations: 40,
    population: 60,
    show_progress: true
  )

IO.inspect(best, label: "🏆 best hyper-params")
```

### 6.5 UI Layout Optimization

Evolve better user interface layouts:

```elixir
# Start with a basic layout configuration
initial_layout = %{
  sidebar_width: 250,
  header_height: 80,
  content_padding: 20,
  font_size: 14,
  button_spacing: 10,
  color_scheme: :light
}

# Define what makes a UI "good"
ui_scorer = fn layout ->
  # Run automated UI tests and user simulation
  usability_score = MyApp.UITests.measure_usability(layout)
  accessibility_score = MyApp.AccessibilityChecker.score(layout)
  aesthetic_score = MyApp.DesignMetrics.visual_appeal(layout)
  
  # Weighted combination
  0.5 * usability_score + 0.3 * accessibility_score + 0.2 * aesthetic_score
end

# Evolve better UI
better_ui = Jido.Evolve.search_best(initial_layout,
  score: ui_scorer,
  generations: 40,
  show_progress: true
)

IO.puts "🎨 Optimized UI layout: #{inspect(better_ui)}"
```

### 6.6 Algorithm Configuration Evolution

Find the perfect settings for your custom algorithms:

```elixir
# Evolve cache replacement algorithm parameters
cache_config = %{
  max_size: 1000,
  ttl_seconds: 300,
  eviction_strategy: :lru,
  prefetch_threshold: 0.8,
  compression_level: 3
}

cache_scorer = fn config ->
  # Run cache simulation with real traffic patterns
  {hit_rate, avg_latency} = MyApp.CacheSimulator.run(config, traffic_log: "prod.log")
  
  # Balance hit rate vs latency
  hit_rate * 100 - avg_latency  # higher hit rate good, lower latency good
end

optimal_cache = Jido.Evolve.search_best(cache_config,
  score: cache_scorer,
  generations: 35,
  population: 40
)
```

### 6.7 String target with mid-level API

```elixir
problem =
  Jido.Evolve.StringTarget.problem("Hxllo", target: "Hello")
  |> Jido.Evolve.Problem.with_generations(200)
  |> Jido.Evolve.Problem.with_show_progress(true)

solution = Jido.Evolve.Problem.run(problem)
#=> %{best: "Hello", score: 1.0, generation: 42}
```

### 6.8 Advanced—swap in your own mutation but keep "easy" layers

```elixir
problem =
  Jido.Evolve.Math.Maximize.problem(&my_equation/1, initial: 0.5)
  |> Jido.Evolve.Problem.with_tweak_strategy(MyCustomMutator)

Jido.Evolve.Problem.run(problem)
```

---

## 7. Implementation Sketch

1. `Jido.Evolve.Problem` struct  
   ```elixir
   defstruct [:initial, :scorer, :opts]
   ```
2. `Jido.Evolve.quick_solve/2` simply calls `StringTarget.problem/2 |> Problem.run/1`.
3. `Problem.run/1` converts to internal config and delegates to `Jido.Evolve.Engine`.
4. Default components live in `Jido.Evolve.BuiltIns.*`; mapping table:

   User option         | Engine component
   --------------------|--------------------
   :tweak_strategy     | Jido.Evolve.Mutation.\*
   :selection_strategy | Jido.Evolve.Selection.\*
   :representation     | Evolvable impl

5. Public docs list *"If you need X, require Y module"* to bridge to advanced API.

---

## 8. Example Directory Layout

```
lib/jido_evolve
├── easy/
│   ├── quick.ex          # quick_solve, tune, search_best
│   ├── problem.ex        # Problem struct + helpers
│   ├── defaults.ex
│   └── built_ins/
│       ├── string_target.ex
│       ├── math.ex
│       └── params.ex
└── (existing engine untouched)
```

---

## 9. Summary

• A **three-tier API** (one-liner → Problem → Engine) lets beginners ship day-one while power users keep full control.  
• Friendly naming, defaults, and examples remove the evolutionary-algorithm barrier.  
• All additions are thin wrappers; no rewrite of the proven core required.  

This design keeps Jido.Evolve powerful for researchers yet *approachable* for everyday Elixir developers.
