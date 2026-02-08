# GEPA: Genetic-Evolutionary Prompt Architecture with Jido.Evolve

*Automatic prompt optimization through evolutionary algorithms and reflective learning*

## Overview

GEPA (Genetic-Evolutionary Prompt Architecture) is a revolutionary approach to prompt optimization that uses **language itself as a learning signal**. Instead of relying on scalar rewards or manual tweaking, GEPA evolves better prompts by reflecting on LLM execution traces and using evolutionary search to discover optimal instruction patterns.

This document shows how to implement GEPA-style prompt optimization using Jido.Evolve's evolutionary framework combined with ReqLLM for LLM interactions.

## Core Concepts

1. **Language-Native Learning**: LLMs learn from their own execution traces, errors, and reasoning paths
2. **Reflective Evolution**: Prompts evolve based on natural language feedback about what worked/failed  
3. **Multi-Objective Optimization**: Maintain diverse prompt populations rather than converging on single solutions
4. **Instruction-Only Focus**: Optimize through better instructions, not few-shot examples

## Quick Start Example

```elixir
# Define your task and success criteria
task = "Extract structured data from customer emails"
success_fn = fn response -> 
  # Measure accuracy, completeness, format correctness
  MyApp.EmailParser.evaluate_extraction(response)
end

# Let GEPA evolve the perfect prompt
optimal_prompt = Jido.Evolve.PromptEvolution.optimize(
  initial_prompt: "Extract the key information from this email",
  task_examples: load_test_emails(),
  success_function: success_fn,
  llm_provider: "anthropic:claude-3-sonnet",
  generations: 20,
  show_progress: true
)

IO.puts "🧬 Evolved prompt: #{optimal_prompt.text}"
IO.puts "📊 Success rate: #{optimal_prompt.score * 100}%"
```

## Detailed Implementation

### 1. Prompt Representation

```elixir
defmodule Jido.Evolve.Prompt do
  @moduledoc """
  Represents an evolvable prompt with metadata and performance tracking.
  """
  
  defstruct [
    :text,           # The actual prompt text
    :components,     # Structured components (system, user, examples)
    :metadata,       # Evolution history, generation, parent prompts
    :performance,    # Success metrics across different tasks
    :constraints     # Length limits, safety requirements
  ]
  
  def new(text, opts \\ []) do
    %__MODULE__{
      text: text,
      components: parse_components(text),
      metadata: %{
        generation: 0,
        created_at: DateTime.utc_now(),
        mutations: []
      },
      performance: %{},
      constraints: Keyword.get(opts, :constraints, default_constraints())
    }
  end
  
  defp parse_components(text) do
    # Extract system messages, instructions, examples, etc.
    %{
      system_message: extract_system_message(text),
      instructions: extract_instructions(text),
      examples: extract_examples(text),
      constraints: extract_constraints(text)
    }
  end
end
```

### 2. LLM Execution and Trace Collection

```elixir
defmodule Jido.Evolve.PromptEvolution.Executor do
  @moduledoc """
  Executes prompts against LLMs and collects detailed traces for reflection.
  """
  
  def execute_with_tracing(prompt, test_case, llm_config) do
    start_time = System.monotonic_time(:millisecond)
    
    # Set up tracing context
    trace = %{
      prompt: prompt.text,
      input: test_case.input,
      expected: test_case.expected,
      execution_steps: []
    }
    
    # Execute with ReqLLM
    result = case ReqLLM.generate_text(llm_config.model, prompt.text <> test_case.input) do
      {:ok, response} ->
        trace = add_step(trace, :llm_response, %{
          response: response,
          tokens_used: count_tokens(response),
          duration_ms: System.monotonic_time(:millisecond) - start_time
        })
        
        # Evaluate success
        success_score = llm_config.success_function.(response, test_case)
        
        {:ok, %{
          response: response,
          success_score: success_score,
          trace: trace
        }}
        
      {:error, error} ->
        trace = add_step(trace, :error, %{error: error})
        {:error, trace}
    end
    
    result
  end
  
  defp add_step(trace, step_type, data) do
    step = %{
      type: step_type,
      timestamp: DateTime.utc_now(),
      data: data
    }
    Map.update!(trace, :execution_steps, &[step | &1])
  end
end
```

### 3. Reflective Feedback Generation

```elixir
defmodule Jido.Evolve.PromptEvolution.Reflector do
  @moduledoc """
  Analyzes execution traces and generates natural language feedback
  for prompt improvement using a separate LLM.
  """
  
  def generate_feedback(execution_results, reflection_config) do
    # Collect traces from multiple executions
    traces = Enum.map(execution_results, & &1.trace)
    
    # Identify patterns in successes and failures
    analysis = analyze_patterns(traces)
    
    # Generate improvement suggestions using reflection LLM
    reflection_prompt = build_reflection_prompt(analysis)
    
    {:ok, feedback} = ReqLLM.generate_text(
      reflection_config.model,
      reflection_prompt,
      temperature: 0.3  # More focused reflection
    )
    
    parse_feedback_suggestions(feedback)
  end
  
  defp analyze_patterns(traces) do
    successes = Enum.filter(traces, &(&1.success_score > 0.7))
    failures = Enum.filter(traces, &(&1.success_score < 0.3))
    
    %{
      success_patterns: extract_common_patterns(successes),
      failure_patterns: extract_common_patterns(failures),
      performance_metrics: calculate_metrics(traces)
    }
  end
  
  defp build_reflection_prompt(analysis) do
    """
    You are an expert prompt engineer analyzing LLM execution traces.
    
    SUCCESSFUL EXECUTIONS:
    #{format_patterns(analysis.success_patterns)}
    
    FAILED EXECUTIONS:
    #{format_patterns(analysis.failure_patterns)}
    
    PERFORMANCE METRICS:
    - Average success rate: #{analysis.performance_metrics.avg_success}
    - Token efficiency: #{analysis.performance_metrics.tokens_per_success}
    - Common error types: #{Enum.join(analysis.performance_metrics.error_types, ", ")}
    
    Based on this analysis, provide 3-5 specific suggestions for improving the prompt:
    1. What should be added to the prompt?
    2. What should be removed or changed?
    3. How can the instructions be clearer?
    4. What constraints or examples would help?
    
    Format your response as actionable mutations:
    ADD: [specific text to add]
    REMOVE: [specific text to remove]  
    REPLACE: [old text] -> [new text]
    RESTRUCTURE: [description of structural change]
    """
  end
end
```

### 4. Evolutionary Prompt Mutations

```elixir
defmodule Jido.Evolve.PromptEvolution.Mutator do
  @moduledoc """
  Implements prompt mutations based on reflective feedback.
  """
  
  @behaviour Jido.Evolve.Mutation
  
  def mutate(%Jido.Evolve.Prompt{} = prompt, %{feedback: feedback} = context) do
    # Apply mutations based on reflection feedback
    mutations = parse_mutation_suggestions(feedback)
    
    mutated_text = Enum.reduce(mutations, prompt.text, fn mutation, acc ->
      apply_mutation(acc, mutation, context)
    end)
    
    # Create new prompt with mutation history
    mutated_prompt = %{prompt | 
      text: mutated_text,
      metadata: Map.update!(prompt.metadata, :mutations, fn muts ->
        [%{type: :reflection_based, feedback: feedback, timestamp: DateTime.utc_now()} | muts]
      end)
    }
    
    {:ok, mutated_prompt}
  end
  
  defp apply_mutation(text, %{type: :add, content: content, position: pos}, _context) do
    insert_at_position(text, content, pos)
  end
  
  defp apply_mutation(text, %{type: :remove, pattern: pattern}, _context) do
    String.replace(text, pattern, "")
  end
  
  defp apply_mutation(text, %{type: :replace, old: old, new: new}, _context) do
    String.replace(text, old, new)
  end
  
  defp apply_mutation(text, %{type: :restructure, description: desc}, context) do
    # Use LLM to restructure based on description
    restructure_with_llm(text, desc, context.llm_config)
  end
  
  # Crossover between high-performing prompts
  def crossover(prompt1, prompt2, context) do
    # Extract best components from each prompt
    comp1 = prompt1.components
    comp2 = prompt2.components
    
    # Intelligently combine components
    hybrid_components = %{
      system_message: select_better_component(comp1.system_message, comp2.system_message, context),
      instructions: merge_instructions(comp1.instructions, comp2.instructions),
      examples: select_diverse_examples(comp1.examples, comp2.examples),
      constraints: merge_constraints(comp1.constraints, comp2.constraints)
    }
    
    # Reconstruct prompt text
    hybrid_text = reconstruct_prompt(hybrid_components)
    
    Jido.Evolve.Prompt.new(hybrid_text, metadata: %{
      parents: [prompt1.metadata.id, prompt2.metadata.id],
      crossover_method: :intelligent_component_merge
    })
  end
end
```

### 5. Multi-Objective Fitness Evaluation

```elixir
defmodule Jido.Evolve.PromptEvolution.Fitness do
  @moduledoc """
  Evaluates prompts across multiple objectives: accuracy, efficiency, safety, etc.
  """
  
  @behaviour Jido.Evolve.Fitness
  
  def evaluate(prompt, context) do
    test_cases = context.test_cases
    llm_config = context.llm_config
    
    # Execute prompt against all test cases
    results = Enum.map(test_cases, fn test_case ->
      Jido.Evolve.PromptEvolution.Executor.execute_with_tracing(prompt, test_case, llm_config)
    end)
    
    # Calculate multi-objective scores
    scores = %{
      accuracy: calculate_accuracy(results),
      efficiency: calculate_efficiency(results),
      consistency: calculate_consistency(results), 
      safety: calculate_safety(results, context.safety_config),
      cost: calculate_cost_efficiency(results)
    }
    
    # Weighted combination or Pareto ranking
    overall_score = case context.optimization_strategy do
      :weighted -> weighted_score(scores, context.weights)
      :pareto -> pareto_rank(scores, context.population)
    end
    
    {:ok, overall_score, metadata: %{
      detailed_scores: scores,
      execution_results: results,
      timestamp: DateTime.utc_now()
    }}
  end
  
  defp calculate_accuracy(results) do
    success_results = Enum.filter(results, &match?({:ok, _}, &1))
    if Enum.empty?(success_results), do: 0.0, else:
      success_results
      |> Enum.map(&(&1.success_score))
      |> Enum.sum()
      |> Kernel./(length(success_results))
  end
  
  defp calculate_efficiency(results) do
    # Tokens per successful result
    successful = Enum.filter(results, &(&1.success_score > 0.5))
    if Enum.empty?(successful), do: 0.0, else:
      total_tokens = Enum.sum(Enum.map(successful, &count_tokens(&1.response)))
      length(successful) / total_tokens  # Higher is better
  end
end
```

### 6. Complete GEPA Implementation

```elixir
defmodule Jido.Evolve.PromptEvolution do
  @moduledoc """
  Main interface for GEPA-style prompt optimization using Jido.Evolve.
  """
  
  def optimize(opts) do
    config = build_config(opts)
    
    # Create initial population of prompts
    initial_population = generate_initial_prompts(config)
    
    # Set up evolutionary configuration
    evolution_config = Jido.Evolve.Config.new!(
      population_size: config.population_size,
      generations: config.generations,
      mutation_rate: config.mutation_rate,
      crossover_rate: config.crossover_rate,
      selection_strategy: Jido.Evolve.Selection.Pareto,  # Multi-objective
      elitism_rate: 0.1
    )
    
    # Define the fitness context
    fitness_context = %{
      test_cases: config.test_cases,
      llm_config: config.llm_config,
      success_function: config.success_function,
      safety_config: config.safety_config,
      optimization_strategy: :pareto
    }
    
    # Run evolution with progress tracking
    evolution_stream = Jido.Evolve.Engine.evolve(
      initial_population,
      evolution_config,
      Jido.Evolve.PromptEvolution.Fitness,
      Jido.Evolve.Evolvable.Prompt,
      mutation: Jido.Evolve.PromptEvolution.Mutator,
      selection: Jido.Evolve.Selection.Pareto,
      context: fitness_context
    )
    
    # Collect results with reflection feedback
    results = evolution_stream
    |> Stream.map(&add_reflection_feedback(&1, config))
    |> Stream.take_while(&continue_evolution?(&1, config))
    |> Enum.to_list()
    
    # Return best prompt(s) from Pareto front
    final_generation = List.last(results)
    best_prompts = extract_pareto_front(final_generation.population)
    
    %{
      best_prompts: best_prompts,
      evolution_history: results,
      final_metrics: calculate_final_metrics(best_prompts),
      recommendations: generate_usage_recommendations(best_prompts)
    }
  end
  
  defp add_reflection_feedback(generation_state, config) do
    if rem(generation_state.generation, 5) == 0 do  # Reflect every 5 generations
      feedback = Jido.Evolve.PromptEvolution.Reflector.generate_feedback(
        generation_state.evaluation_results,
        config.reflection_config
      )
      
      Map.put(generation_state, :reflection_feedback, feedback)
    else
      generation_state
    end
  end
end
```

## Real-World Use Cases

### 1. Customer Support Bot Optimization

```elixir
# Evolve prompts for better customer service responses
support_config = %{
  initial_prompt: "You are a helpful customer support agent. Respond professionally.",
  test_cases: load_support_tickets(),
  success_function: fn response, ticket -> 
    %{
      helpfulness: rate_helpfulness(response),
      accuracy: check_factual_accuracy(response, ticket.context),
      politeness: measure_tone(response),
      resolution_likelihood: predict_resolution(response, ticket)
    }
  end,
  llm_provider: "anthropic:claude-3-sonnet",
  safety_config: %{avoid_topics: ["legal advice", "medical advice"]},
  generations: 30
}

optimized = Jido.Evolve.PromptEvolution.optimize(support_config)
```

### 2. Code Generation Prompt Evolution

```elixir
# Optimize prompts for generating better code
code_config = %{
  initial_prompt: "Generate clean, efficient code that solves this problem:",
  test_cases: load_programming_challenges(),
  success_function: fn code, challenge ->
    %{
      correctness: run_test_suite(code, challenge.tests),
      efficiency: measure_performance(code, challenge.benchmarks),
      readability: analyze_code_quality(code),
      security: scan_security_issues(code)
    }
  end,
  llm_provider: "openai:gpt-4-turbo",
  constraints: %{max_tokens: 2000, require_comments: true}
}

code_optimizer = Jido.Evolve.PromptEvolution.optimize(code_config)
```

### 3. Content Creation Optimization

```elixir
# Evolve prompts for better marketing copy
marketing_config = %{
  initial_prompt: "Write compelling marketing copy for this product:",
  test_cases: load_product_descriptions(),
  success_function: fn copy, product ->
    %{
      engagement: predict_engagement_score(copy),
      conversion: estimate_conversion_rate(copy, product.target_audience),
      brand_alignment: measure_brand_consistency(copy, product.brand_guidelines),
      readability: calculate_readability_score(copy)
    }
  end,
  reflection_config: %{
    model: "anthropic:claude-3-haiku",  # Faster model for reflection
    focus_areas: [:emotional_appeal, :call_to_action, :value_proposition]
  }
}

marketing_optimizer = Jido.Evolve.PromptEvolution.optimize(marketing_config)
```

## Advanced Features

### Prompt Component Evolution

```elixir
# Evolve different parts of prompts independently
component_evolution = %{
  system_message: Jido.Evolve.PromptEvolution.evolve_component(:system),
  instructions: Jido.Evolve.PromptEvolution.evolve_component(:instructions), 
  examples: Jido.Evolve.PromptEvolution.evolve_component(:examples),
  constraints: Jido.Evolve.PromptEvolution.evolve_component(:constraints)
}
```

### Multi-Model Optimization

```elixir
# Optimize prompts across different LLM models
multi_model_config = %{
  models: [
    "anthropic:claude-3-sonnet",
    "openai:gpt-4-turbo", 
    "google:gemini-pro"
  ],
  cross_model_validation: true,
  model_specific_adaptations: true
}
```

### Safety-Constrained Evolution

```elixir
# Ensure evolved prompts maintain safety standards
safety_constraints = %{
  toxicity_threshold: 0.01,
  bias_detection: true,
  content_filters: [:violence, :hate_speech, :misinformation],
  human_review_triggers: [:low_confidence, :edge_cases]
}
```

## Performance Considerations

1. **Batch Processing**: Execute multiple test cases in parallel
2. **Caching**: Cache LLM responses for identical inputs
3. **Early Termination**: Stop evolution when improvements plateau
4. **Resource Limits**: Set token budgets and time constraints
5. **Model Selection**: Use faster models for reflection, premium models for final evaluation

## Integration with Existing Systems

```elixir
# Integrate GEPA with your existing prompt management
defmodule MyApp.PromptManager do
  def optimize_prompt(prompt_id, config) do
    current_prompt = get_prompt(prompt_id)
    
    optimized = Jido.Evolve.PromptEvolution.optimize(%{
      initial_prompt: current_prompt.text,
      test_cases: generate_test_cases(prompt_id),
      success_function: &evaluate_business_metrics/2
    })
    
    # A/B test the evolved prompt
    schedule_ab_test(current_prompt, optimized.best_prompts)
  end
end
```

## Conclusion

GEPA represents a paradigm shift in prompt engineering - from manual craft to automated evolution. By combining Jido.Evolve's powerful evolutionary algorithms with ReqLLM's LLM integration, we can automatically discover prompts that outperform human-crafted versions across multiple objectives.

The key insights:
- **Language as learning signal**: Use rich textual feedback instead of scalar rewards
- **Multi-objective optimization**: Balance accuracy, efficiency, safety, and cost
- **Reflective improvement**: LLMs can critique and improve their own instructions
- **Systematic exploration**: Evolutionary search discovers non-obvious prompt patterns

This approach scales to any domain where prompt quality matters, from customer service to code generation to creative writing.
