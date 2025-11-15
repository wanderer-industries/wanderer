defmodule WandererApp.Api.ActorWithMap do
  @moduledoc """
  Wraps a user and map together for token-only authentication.

  This allows us to pass both the authenticated user AND the map
  identified by the token through to Ash actions via the actor field.

  This struct implements the Access behavior, delegating field access
  transparently to the user for compatibility with authorization policies.

  ## Examples

      iex> actor = ActorWithMap.new(user, map)
      iex> actor[:id]  # Access user.id
      "user-123"
      iex> actor.user  # Direct user access
      %User{}
      iex> actor.map   # Direct map access
      %Map{}
  """

  @behaviour Access

  defstruct [:user, :map]

  @type t :: %__MODULE__{
          user: WandererApp.Api.User.t(),
          map: WandererApp.Api.Map.t()
        }

  def new(user, map) do
    %__MODULE__{user: user, map: map}
  end

  def user(%__MODULE__{user: user}), do: user
  def map(%__MODULE__{map: map}), do: map

  @impl Access
  def fetch(%__MODULE__{user: user}, key) when is_atom(key) or is_binary(key) do
    Map.fetch(user, key)
  end

  @impl Access
  def get_and_update(%__MODULE__{user: user} = actor, key, fun) do
    {get_value, updated_user} = Map.get_and_update(user, key, fun)
    {get_value, %{actor | user: updated_user}}
  end

  @impl Access
  def pop(%__MODULE__{user: user} = actor, key) do
    {value, updated_user} = Map.pop(user, key)
    {value, %{actor | user: updated_user}}
  end
end
