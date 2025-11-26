defmodule WandererApp.Api.ActorHelpers do
  @moduledoc """
  Utilities for extracting actor information from Ash contexts.

  Provides helper functions for working with ActorWithMap and extracting
  user, map, and character information from various context formats.
  """

  alias WandererApp.Api.ActorWithMap

  @doc """
  Extract map from actor or context.

  Handles various context formats:
  - Direct ActorWithMap struct
  - Context map with :actor key
  - Context map with :map key
  - Ash.Resource.Change.Context struct
  """
  def get_map(%{actor: %ActorWithMap{map: %{} = map}}), do: map
  def get_map(%{map: %{} = map}), do: map

  # Handle Ash.Resource.Change.Context struct
  def get_map(%Ash.Resource.Change.Context{actor: %ActorWithMap{map: %{} = map}}), do: map
  def get_map(%Ash.Resource.Change.Context{actor: _}), do: nil

  def get_map(context) when is_map(context) do
    # For plain maps, check private.actor
    with private when is_map(private) <- Map.get(context, :private),
         %ActorWithMap{map: %{} = map} <- Map.get(private, :actor) do
      map
    else
      _ -> nil
    end
  end

  def get_map(_), do: nil

  @doc """
  Extract user from actor.

  Handles:
  - ActorWithMap struct
  - Direct user struct with :id field
  """
  def get_user(%ActorWithMap{user: user}), do: user
  def get_user(%{id: _} = user), do: user
  def get_user(_), do: nil

  @doc """
  Get character IDs for the actor.

  Used for ACL filtering to determine which resources the user can access.
  Returns {:ok, list} or {:ok, []} if no characters found.
  """
  def get_character_ids(%ActorWithMap{user: user}), do: get_character_ids(user)

  def get_character_ids(%{characters: characters}) when is_list(characters) do
    {:ok, Enum.map(characters, & &1.id)}
  end

  def get_character_ids(%{characters: %Ecto.Association.NotLoaded{}, id: user_id}) do
    # Load characters from database
    load_characters_by_id(user_id)
  end

  def get_character_ids(%{id: user_id}) do
    # Fallback: load user with characters
    load_characters_by_id(user_id)
  end

  def get_character_ids(_), do: {:ok, []}

  defp load_characters_by_id(user_id) do
    case WandererApp.Api.User.by_id(user_id, load: [:characters]) do
      {:ok, user} -> {:ok, Enum.map(user.characters, & &1.id)}
      _ -> {:ok, []}
    end
  end
end
