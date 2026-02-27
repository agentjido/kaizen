defmodule Jido.Evolve.Error do
  @moduledoc """
  Centralized error handling for Jido.Evolve using Splode.
  """

  use Splode,
    error_classes: [
      invalid: Invalid,
      execution: Execution,
      config: Config,
      internal: Internal
    ],
    unknown_error: Jido.Evolve.Error.Internal.UnknownError

  defmodule Invalid do
    @moduledoc "Invalid input error class."
    use Splode.ErrorClass, class: :invalid
  end

  defmodule Execution do
    @moduledoc "Execution error class."
    use Splode.ErrorClass, class: :execution
  end

  defmodule Config do
    @moduledoc "Configuration error class."
    use Splode.ErrorClass, class: :config
  end

  defmodule Internal do
    @moduledoc "Internal error class."
    use Splode.ErrorClass, class: :internal

    defmodule UnknownError do
      @moduledoc false
      defexception [:message, :details]
    end
  end

  defmodule InvalidInputError do
    @moduledoc "Error raised for invalid input."
    defexception [:message, :field, :value, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            field: atom() | nil,
            value: any() | nil,
            details: map() | nil
          }
  end

  defmodule ConfigError do
    @moduledoc "Error raised for invalid configuration."
    defexception [:message, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            details: map() | nil
          }
  end

  defmodule ExecutionError do
    @moduledoc "Error raised for execution failures."
    defexception [:message, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            details: map() | nil
          }
  end

  defmodule InternalError do
    @moduledoc "Error raised for unexpected internal failures."
    defexception [:message, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            details: map() | nil
          }
  end

  @doc "Build an invalid input error."
  @spec validation_error(String.t(), map()) :: InvalidInputError.t()
  def validation_error(message, details \\ %{}) do
    InvalidInputError.exception(
      message: message,
      field: Map.get(details, :field),
      value: Map.get(details, :value),
      details: details
    )
  end

  @doc "Build a configuration error."
  @spec config_error(String.t(), map()) :: ConfigError.t()
  def config_error(message, details \\ %{}) do
    ConfigError.exception(message: message, details: details)
  end

  @doc "Build an execution error."
  @spec execution_error(String.t(), map()) :: ExecutionError.t()
  def execution_error(message, details \\ %{}) do
    ExecutionError.exception(message: message, details: details)
  end

  @doc "Build an internal error."
  @spec internal_error(String.t(), map()) :: InternalError.t()
  def internal_error(message, details \\ %{}) do
    InternalError.exception(message: message, details: details)
  end
end
