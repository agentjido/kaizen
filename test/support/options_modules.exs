defmodule TestOptions.MissingEvaluateFitness do
  @moduledoc false
end

defmodule TestOptions.InvalidMutationModule do
  @moduledoc false
  def nope, do: :ok
end

defmodule TestOptions.InvalidSelectionModule do
  @moduledoc false
  def nope, do: :ok
end

defmodule TestOptions.InvalidCrossoverModule do
  @moduledoc false
  def nope, do: :ok
end
