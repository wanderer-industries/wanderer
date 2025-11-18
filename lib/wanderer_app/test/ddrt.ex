defmodule WandererApp.Test.DDRT do
  @moduledoc """
  Behaviour for DDRT functions used in the application.
  This allows mocking of DDRT calls in tests.
  """

  @callback init_tree(String.t(), map()) :: :ok | {:error, term()}
  @callback insert({integer(), any()} | list({integer(), any()}), String.t()) ::
              {:ok, map()} | {:error, term()}
  @callback update(integer(), any(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback delete(integer() | [integer()], String.t()) :: {:ok, map()} | {:error, term()}
  @callback query(any(), String.t()) :: {:ok, [any()]} | {:error, term()}
end
