defmodule WandererApp.Api.ActorHelpers do
  @moduledoc """
  Utilities for extracting actor information from Ash contexts.

  Provides consistent actor handling across Ash preparations,
  changes, and validations.
  """

  alias WandererApp.Api.ActorWithMap

  @doc """
  Extracts the map from an actor or context.

  Returns the map from:
  1. ActorWithMap.map (token-based auth)
  2. context[:map] (fallback for tests/internal)
  3. nil (no map context)

  ## Examples

      iex> get_map(%{actor: %ActorWithMap{map: %Map{id: "123"}}})
      %Map{id: "123"}

      iex> get_map(%{map: %Map{id: "456"}})
      %Map{id: "456"}

      iex> get_map(%{actor: %User{}})
      nil
  """
  def get_map(%{actor: %ActorWithMap{map: map}}) when not is_nil(map), do: map
  def get_map(%{map: map}) when not is_nil(map), do: map

  def get_map(context) when is_map(context) do
    # Fallback: check private actor
    case get_in(context, [:private, :actor]) do
      %ActorWithMap{map: map} when not is_nil(map) -> map
      _ -> nil
    end
  end

  def get_map(_), do: nil

  @doc """
  Extracts character IDs for ACL filtering.

  Returns `{:ok, character_ids}` or `{:error, reason}`.

  Handles:
  - ActorWithMap with user
  - Direct user actor
  - Preloaded vs not-preloaded characters

  ## Examples

      iex> get_character_ids(%ActorWithMap{user: %{characters: [%{id: "c1"}]}})
      {:ok, ["c1"]}

      iex> get_character_ids(%User{characters: []})
      {:ok, []}
  """
  def get_character_ids(%ActorWithMap{user: user}), do: get_character_ids(user)

  def get_character_ids(%{characters: characters} = user) when is_list(characters) do
    if user_id = Map.get(user, :id) do
      :telemetry.execute(
        [:wanderer_app, :filter, :characters_preloaded],
        %{count: 1},
        %{user_id: user_id}
      )
    end

    character_ids = Enum.map(characters, & &1.id)
    {:ok, character_ids}
  end

  # Handle Ecto's NotLoaded marker
  def get_character_ids(%{characters: %Ecto.Association.NotLoaded{}} = user) do
    load_characters(user)
  end

  # Handle Ash's NotLoaded marker
  def get_character_ids(%{characters: %Ash.NotLoaded{}} = user) do
    load_characters(user)
  end

  # Fallback for invalid actors
  def get_character_ids(_actor) do
    {:error, :invalid_actor_for_character_extraction}
  end

  defp load_characters(user) do
    user_id = Map.get(user, :id)

    if user_id do
      :telemetry.execute(
        [:wanderer_app, :filter, :characters_lazy_loaded],
        %{count: 1},
        %{user_id: user_id}
      )
    end

    case Ash.load(user, :characters) do
      {:ok, loaded_user} ->
        character_ids = Enum.map(loaded_user.characters, & &1.id)
        {:ok, character_ids}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Extracts user from actor.

  ## Examples

      iex> get_user(%ActorWithMap{user: %User{id: "u1"}})
      %User{id: "u1"}

      iex> get_user(%User{id: "u2"})
      %User{id: "u2"}
  """
  def get_user(%ActorWithMap{user: user}), do: user
  def get_user(%{__struct__: WandererApp.Api.User} = user), do: user
  def get_user(_), do: nil
end
