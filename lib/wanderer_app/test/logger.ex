defmodule WandererApp.Test.Logger do
  @moduledoc """
  Behaviour for logger functions used in the application.
  This allows mocking of logger calls in tests.
  """

  @callback info(message :: iodata() | (-> iodata())) :: :ok
  @callback error(message :: iodata() | (-> iodata())) :: :ok
  @callback warning(message :: iodata() | (-> iodata())) :: :ok
  @callback debug(message :: iodata() | (-> iodata())) :: :ok
end
