defmodule WandererApp.Api.ActorWithMap do
  @moduledoc """
  Wraps a user and map together as an actor for token-based authentication.

  When API requests use Bearer token auth, the token identifies both the user
  (map owner) and the map. This struct allows passing both through Ash's actor system.
  """

  @enforce_keys [:user, :map]
  defstruct [:user, :map]

  def new(user, map) do
    %__MODULE__{user: user, map: map}
  end
end
