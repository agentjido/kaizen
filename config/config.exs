import Config

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :generation,
    :population_size,
    :best_score,
    :diversity,
    :evaluated_count,
    :offspring_count,
    :elite_count,
    :details
  ]
