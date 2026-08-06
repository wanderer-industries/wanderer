defmodule WandererApp.Map.EveTokenAuth do
  @moduledoc """
  Exchanges an EVE SSO access token for a short-lived, map-scoped API token.

  This is an additive alternative to the static, shared `map.public_api_key`
  (see `WandererAppWeb.Plugs.CheckMapApiKey`). Instead of possession of a
  secret, access follows the caller's actual EVE identity:

    1. The caller's EVE SSO access token is verified via `WandererApp.EveSso`.
    2. The resulting character is checked against the map's ACLs using
       `WandererApp.Permissions.check_characters_access/2` - the exact same
       owner/character/corporation/alliance role logic already used for
       session-based (web UI) access.
    3. On success, a signed token encoding the map and the resulting
       permission mask is returned, valid for `@token_ttl` seconds.

  ## Known limitation (open question for review)

  The character must already exist in Wanderer's `character_v1` table (i.e.
  it has logged into Wanderer at least once via the web SSO flow, or is
  otherwise tracked) - this module does not create characters on the fly.
  Corp/alliance-wide ACL entries therefore only grant access to characters
  Wanderer has already seen at least once, even though their corp/alliance
  membership could in principle be resolved from public ESI data alone.
  Whether to add a public-ESI fallback lookup for entirely unknown
  characters is left as a follow-up decision (see CLAUDE.md).
  """

  alias WandererApp.Api.Map, as: MapApi
  alias WandererApp.Api.Character, as: CharacterApi

  @eve_sso Application.compile_env(:wanderer_app, :eve_sso, WandererApp.EveSso)
  @salt "map_eve_auth_v1"
  @token_ttl 15 * 60

  @doc """
  Validates an EVE SSO access token against a map's ACLs and, on success,
  returns a signed, map-scoped token plus the resolved permission set.
  """
  @spec exchange(String.t(), String.t()) ::
          {:ok, map()}
          | {:error,
             :map_not_found | :invalid_token | :verify_failed | :character_not_tracked | :forbidden}
  def exchange(map_identifier, eve_access_token) do
    with {:ok, map} <- resolve_map(map_identifier),
         {:ok, eve_character} <- @eve_sso.verify_token(eve_access_token),
         {:ok, character} <- resolve_character(eve_character),
         {:ok, map} <- load_acls(map),
         mask when mask not in [0, -1] <- permission_mask(map, character) do
      {:ok,
       %{
         token: sign_token(map, character),
         token_type: "Bearer",
         expires_in: @token_ttl,
         map_id: map.id,
         character: %{eve_id: character.eve_id, name: eve_character.character_name},
         permissions: WandererApp.Permissions.get_permissions(mask)
       }}
    else
      mask when is_integer(mask) -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies a token minted by `exchange/2`. Intended for use by
  `WandererAppWeb.Plugs.CheckMapApiKey` as an alternative to the static
  map key check.
  """
  @spec verify(String.t()) ::
          {:ok, %{map_id: String.t(), character_eve_id: String.t()}} | {:error, :invalid}
  def verify(token) do
    case Phoenix.Token.verify(WandererAppWeb.Endpoint, @salt, token, max_age: @token_ttl) do
      {:ok, payload} -> {:ok, payload}
      {:error, _reason} -> {:error, :invalid}
    end
  end

  defp sign_token(map, character) do
    Phoenix.Token.sign(WandererAppWeb.Endpoint, @salt, %{
      map_id: map.id,
      character_eve_id: character.eve_id
    })
  end

  defp resolve_map(identifier) do
    case Ecto.UUID.cast(identifier) do
      {:ok, _} ->
        case MapApi.by_id(identifier) do
          {:ok, map} -> {:ok, map}
          _ -> resolve_by_slug(identifier)
        end

      :error ->
        resolve_by_slug(identifier)
    end
  end

  defp resolve_by_slug(slug) do
    case MapApi.get_map_by_slug(slug) do
      {:ok, map} -> {:ok, map}
      _ -> {:error, :map_not_found}
    end
  end

  # Mirrors WandererApp.Permissions.get_map_permissions/3 (used for the web
  # session actor): the map owner always gets admin rights, regardless of
  # ACL entries. check_characters_access/2 only knows about ACL-level
  # ownership (AccessList.owner_id), not map ownership, so this has to be
  # handled separately here.
  defp permission_mask(%{owner_id: owner_id} = _map, %{id: character_id})
       when not is_nil(owner_id) and owner_id == character_id do
    WandererApp.Permissions.role_mask(:admin)
  end

  defp permission_mask(map, character) do
    map.acls
    |> then(&WandererApp.Permissions.check_characters_access([character], &1))
    |> List.first()
  end

  defp load_acls(map),
    do:
      Ash.load(map,
        acls: [:owner_id, members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]]
      )

  # See "Known limitation" in the moduledoc: only characters Wanderer already
  # tracks can be resolved here.
  defp resolve_character(%{character_id: character_id}) do
    case CharacterApi.by_eve_id(to_string(character_id)) do
      {:ok, character} -> {:ok, character}
      _ -> {:error, :character_not_tracked}
    end
  end
end
