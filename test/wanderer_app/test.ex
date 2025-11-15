defmodule WandererApp.Test do
  defmodule PubSub do
    @type t :: atom
    @type topic :: binary
    @type message :: term

    @callback subscribe(t, topic) :: :ok | {:error, term}
    @callback broadcast(t, topic, message) :: :ok | {:error, term}
  end

  defmodule Logger do
    @type message :: binary

    @callback info(message) :: :ok
    @callback debug(message) :: :ok
    @callback error(message) :: :ok
  end
end
