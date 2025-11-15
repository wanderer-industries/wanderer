defmodule WandererApp.CharacterHelpers do
  @moduledoc """
  Shared helper functions for working with characters.
  """

  @doc """
  Gets the active character ID for an actor.

  Returns the character ID from:
  1. Actor's active_character_id if present
  2. Actor's first non-deleted character
  3. nil if no character found

  ## Examples

      iex> get_active_character_id(%{active_character_id: "char-123"})
      "char-123"

      iex> get_active_character_id(%{id: "user-456"})
      "char-789"  # First character for user

      iex> get_active_character_id(%{})
      nil
  """
  def get_active_character_id(%{active_character_id: id}) when not is_nil(id) do
    id
  end

  def get_active_character_id(%{id: user_id} = actor) do
    # Fetch first non-deleted character for user
    query =
      WandererApp.Api.Character
      |> Ash.Query.for_read(:active_by_user, %{user_id: user_id}, actor: actor)
      |> Ash.Query.limit(1)

    case Ash.read(query) do
      {:ok, [character | _]} -> character.id
      _ -> nil
    end
  end

  def get_active_character_id(_actor), do: nil
end
