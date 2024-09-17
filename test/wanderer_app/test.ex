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

  defmodule DDRT do
    @type id :: number() | String.t()
    @type coord_range :: {number(), number()}
    @type bounding_box :: list(coord_range())
    @type leaf :: {id(), bounding_box()}

    @callback delete(ids :: id() | [id()], name :: GenServer.name()) ::
                {:ok, map()} | {:badtree, map()}
    @callback insert(leaves :: leaf() | [leaf()], name :: GenServer.name()) ::
                {:ok, map()} | {:badtree, map()}
    @callback update(
                ids :: id(),
                box :: bounding_box() | {bounding_box(), bounding_box()},
                name :: GenServer.name()
              ) :: {:ok, map()} | {:badtree, map()}
  end
end
