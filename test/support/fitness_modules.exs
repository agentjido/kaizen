defmodule TestFitnessCases.SimpleFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(number, _context) when is_number(number), do: {:ok, number * 1.0}

  @impl true
  def evaluate(_entity, _context), do: {:error, :invalid_entity}
end

defmodule TestFitnessCases.MetadataFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(string, _context) when is_binary(string) do
    score = String.length(string) / 10.0
    {:ok, %{score: score, metadata: %{length: String.length(string)}}}
  end
end

defmodule TestFitnessCases.MixedFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(entity, context) do
    case entity do
      n when is_number(n) -> {:ok, n * 1.0}
      s when is_binary(s) -> {:ok, %{score: String.length(s) / 10.0}}
      _ -> Map.get(context, :default, {:error, :invalid})
    end
  end
end

defmodule TestFitnessCases.InvalidFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(_entity, %{return: return_value}), do: return_value

  @impl true
  def evaluate(_entity, _context), do: nil
end

defmodule TestFitnessCases.CustomBatchFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(n, _context), do: {:ok, n * 1.0}

  @impl true
  def batch_evaluate(entities, _context) do
    {:ok, Enum.map(entities, fn entity -> {entity, 100.0} end)}
  end
end

defmodule TestFitnessCases.PrecisionFitness do
  @moduledoc false
  use Jido.Evolve.Fitness

  @impl true
  def evaluate(n, _context), do: {:ok, n / 3.0}
end
