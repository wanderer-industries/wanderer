defmodule WandererApp.Test.LoggerStub do
  @moduledoc """
  A stub implementation of the Logger behaviour for testing.
  This provides default implementations that can be used during application startup.
  """

  @behaviour WandererApp.Test.Logger

  @impl true
  def info(_message), do: :ok

  @impl true
  def info(_message, _metadata), do: :ok

  @impl true
  def error(_message), do: :ok

  @impl true
  def error(_message, _metadata), do: :ok

  @impl true
  def warning(_message), do: :ok

  @impl true
  def warning(_message, _metadata), do: :ok

  @impl true
  def debug(_message), do: :ok

  @impl true
  def debug(_message, _metadata), do: :ok
end
