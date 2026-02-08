defimpl Jido.Evolve.Evolvable, for: BitString do
  @moduledoc """
  Implementation of Jido.Evolve.Evolvable for strings.

  Treats strings as lists of characters for evolutionary operations.

  ## Examples

      iex> genome = Jido.Evolve.Evolvable.to_genome("evolve")
      iex> Jido.Evolve.Evolvable.from_genome("evolve", genome)
      "evolve"

      iex> Jido.Evolve.Evolvable.similarity("hello", "hello")
      0.0

      iex> similarity = Jido.Evolve.Evolvable.similarity("hello", "hallo")
      iex> similarity > 0.0 and similarity < 0.5
      true
  """

  @doc """
  Convert string to list of characters (genome).

  ## Examples

      iex> Jido.Evolve.Evolvable.to_genome("hello")
      ~c"hello"

      iex> Jido.Evolve.Evolvable.to_genome("")
      ~c""

      iex> Jido.Evolve.Evolvable.to_genome("🚀")
      [128640]
  """
  def to_genome(string) when is_binary(string) do
    String.to_charlist(string)
  end

  @doc """
  Convert character list back to string.

  ## Examples

      iex> Jido.Evolve.Evolvable.from_genome("original", ~c"hi")
      "hi"

      iex> Jido.Evolve.Evolvable.from_genome("ignored", ~c"new")
      "new"

      iex> Jido.Evolve.Evolvable.from_genome("any", ~c"")
      ""
  """
  def from_genome(_original, charlist) when is_list(charlist) do
    List.to_string(charlist)
  end

  @doc """
  Calculate similarity using Jaro distance (0.0 = identical, 1.0 = completely different).

  ## Examples

      iex> Jido.Evolve.Evolvable.similarity("hello", "hello")
      0.0

      iex> similarity = Jido.Evolve.Evolvable.similarity("hello", "world")
      iex> similarity > 0.0 and similarity <= 1.0
      true

      iex> sim_similar = Jido.Evolve.Evolvable.similarity("test", "tests")
      iex> sim_different = Jido.Evolve.Evolvable.similarity("test", "xyz")
      iex> sim_different > sim_similar
      true
  """
  def similarity(string1, string2) when is_binary(string1) and is_binary(string2) do
    jaro_distance = String.jaro_distance(string1, string2)
    # Invert so 0.0 = identical, 1.0 = completely different
    1.0 - jaro_distance
  end
end
