defmodule WandererApp.Test.DDRT do
  @moduledoc """
  Behaviour for DDRT functions used in the application.
  This allows mocking of DDRT calls in tests.
  """

  @callback insert({integer(), any()}, String.t()) :: :ok | {:error, term()}
  @callback update(integer(), any(), String.t()) :: :ok | {:error, term()}
  @callback delete([integer()], String.t()) :: :ok | {:error, term()}
  @callback search(any(), String.t()) :: [any()]
end
