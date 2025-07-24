defmodule WandererApp.Test.PubSub do
  @moduledoc """
  Behaviour for PubSub functions used in the application.
  This allows mocking of PubSub calls in tests.
  """

  @callback broadcast(
              server :: module() | pid(),
              topic :: String.t(),
              message :: any()
            ) ::
              :ok | {:error, term()}
  @callback broadcast!(
              server :: module() | pid(),
              topic :: String.t(),
              message :: any()
            ) ::
              :ok | {:error, term()}
  @callback subscribe(topic :: String.t()) :: :ok | {:error, term()}
  @callback subscribe(module :: atom(), topic :: String.t()) :: :ok | {:error, term()}
  @callback unsubscribe(topic :: String.t()) :: :ok | {:error, term()}
  @callback unsubscribe(module :: atom(), topic :: String.t()) :: :ok | {:error, term()}
end
