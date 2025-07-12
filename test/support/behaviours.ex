# Define behaviours at the top level to avoid module nesting issues
defmodule WandererApp.Test.PubSub do
  @callback broadcast(atom(), binary(), any()) :: :ok | {:error, any()}
  @callback broadcast!(atom(), binary(), any()) :: :ok
  @callback subscribe(binary()) :: :ok | {:error, any()}
  @callback subscribe(atom(), binary()) :: :ok | {:error, any()}
  @callback unsubscribe(binary()) :: :ok | {:error, any()}
end

defmodule WandererApp.Test.Logger do
  @callback info(binary()) :: :ok
  @callback warning(binary()) :: :ok
  @callback error(binary()) :: :ok
  @callback debug(binary()) :: :ok
end

defmodule WandererApp.Test.DDRT do
  @callback insert(any(), atom()) :: :ok | {:error, any()}
  @callback update(any(), any(), atom()) :: :ok | {:error, any()}
  @callback delete(list(), atom()) :: :ok | {:error, any()}
end
