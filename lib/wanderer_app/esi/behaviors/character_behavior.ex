defmodule WandererApp.Esi.CharacterBehavior do
  @moduledoc """
  Behavior for EVE ESI character API operations.
  """

  @callback get_character_info(character_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback get_character_location(character_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback get_character_online(character_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback get_character_ship(character_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback get_character_wallet(character_id :: String.t(), opts :: keyword()) ::
              {:ok, float()} | {:error, term()}

  @callback post_characters_affiliation(character_ids :: list(String.t()), opts :: keyword()) ::
              {:ok, list(map())} | {:error, term()}
end
