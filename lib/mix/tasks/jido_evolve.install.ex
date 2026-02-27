defmodule Mix.Tasks.JidoEvolve.Install.Docs do
  @moduledoc false

  @doc "Short task description."
  @spec short_doc() :: String.t()
  def short_doc do
    "Install and configure Jido.Evolve for use in an application."
  end

  @doc "Task usage example."
  @spec example() :: String.t()
  def example do
    "mix jido_evolve.install"
  end

  @doc "Long-form task documentation."
  @spec long_doc() :: String.t()
  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.JidoEvolve.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :jido_evolve,
        adds_deps: [],
        installs: [],
        example: __MODULE__.Docs.example(),
        only: nil,
        positional: [],
        composes: [],
        schema: [],
        defaults: [],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.add_notice("""
      Jido.Evolve installed successfully.

      Next steps:
      - Read: https://hexdocs.pm/jido_evolve/readme.html
      - Start with: Jido.Evolve.evolve/1
      """)
    end
  end
else
  defmodule Mix.Tasks.JidoEvolve.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'jido_evolve.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
