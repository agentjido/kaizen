defmodule Jido.Evolve.ErrorTest do
  use ExUnit.Case, async: true

  alias Jido.Evolve.Error

  test "validation_error/2 builds invalid input exception" do
    error = Error.validation_error("invalid field", %{field: :fitness, value: :bad, details: %{reason: :oops}})

    assert %Error.InvalidInputError{} = error
    assert error.message == "invalid field"
    assert error.field == :fitness
    assert error.value == :bad
    assert error.details[:details][:reason] == :oops
  end

  test "config_error/2 builds config exception" do
    error = Error.config_error("bad config", %{path: :root})

    assert %Error.ConfigError{} = error
    assert error.message == "bad config"
    assert error.details == %{path: :root}
  end

  test "execution_error/2 builds execution exception" do
    error = Error.execution_error("execution failed", %{step: :mutation})

    assert %Error.ExecutionError{} = error
    assert error.message == "execution failed"
    assert error.details == %{step: :mutation}
  end

  test "internal_error/2 builds internal exception" do
    error = Error.internal_error("unexpected", %{module: :state})

    assert %Error.InternalError{} = error
    assert error.message == "unexpected"
    assert error.details == %{module: :state}
  end
end
