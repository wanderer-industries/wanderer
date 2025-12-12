defmodule WandererAppWeb.AuthController do
  use WandererAppWeb, :controller
  plug Ueberauth

  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user} = _assigns} = conn, _params) do
    active_tracking_pool = WandererApp.Character.TrackingConfigUtils.get_active_pool!()

    character_data = %{
      eve_id: "#{auth.info.email}",
      name: auth.info.name,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at,
      scopes: auth.credentials.scopes,
      tracking_pool: active_tracking_pool
    }

    %{
      "CharacterOwnerHash" => character_owner_hash
    } = auth.extra.raw_info.user

    {:ok, character} =
      case WandererApp.Api.Character.by_eve_id(character_data.eve_id) do
        {:ok, character} ->
          character_update = %{
            name: auth.info.name,
            access_token: auth.credentials.token,
            refresh_token: auth.credentials.refresh_token,
            expires_at: auth.credentials.expires_at,
            scopes: auth.credentials.scopes,
            tracking_pool: active_tracking_pool
          }

          {:ok, character} =
            character
            |> WandererApp.Api.Character.update(character_update)

          WandererApp.Character.update_character(character.id, character_update)

          # Update corporation/alliance data from ESI to ensure access control is current
          update_character_affiliation(character)

          {:ok, character}

        {:error, _error} ->
          {:ok, character} = WandererApp.Api.Character.create(character_data)
          :telemetry.execute([:wanderer_app, :user, :character, :registered], %{count: 1})

          # Fetch initial corporation/alliance data for new characters
          update_character_affiliation(character)

          {:ok, character}
      end

    user_id =
      case user do
        nil ->
          case WandererApp.Api.User.by_hash(character_owner_hash) do
            {:ok, user} ->
              user.id

            _ ->
              case character.user_id do
                nil ->
                  :telemetry.execute([:wanderer_app, :user, :registered], %{count: 1})

                  WandererApp.Api.User
                  |> Ash.Changeset.for_create(:create, %{
                    name: "User_#{character_owner_hash}",
                    hash: character_owner_hash
                  })
                  |> Ash.create!()
                  |> Map.get(:id)

                user_id ->
                  user_id
              end
          end

        user ->
          user.id
      end

    maybe_update_character_user_id(character, user_id)

    WandererApp.Character.TrackingConfigUtils.update_active_tracking_pool()

    conn
    |> put_session(:user_id, user_id)
    |> redirect(to: "/characters")
  end

  def callback(conn, _params) do
    conn
    |> redirect(to: "/characters")
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  def maybe_update_character_user_id(character, user_id) when not is_nil(user_id) do
    # First try to load the character by ID to ensure it exists and is valid
    case WandererApp.Api.Character.by_id(character.id) do
      {:ok, loaded_character} ->
        WandererApp.Api.Character.assign_user!(loaded_character, %{user_id: user_id})

      {:error, _} ->
        raise Ash.Error.Invalid,
          errors: [%Ash.Error.Query.NotFound{resource: WandererApp.Api.Character}]
    end
  end

  def maybe_update_character_user_id(_character, _user_id), do: :ok

  # Updates character's corporation and alliance data from ESI.
  # This ensures ACL-based access control uses current corporation membership,
  # even for characters not actively being tracked on any map.
  defp update_character_affiliation(%{id: character_id, eve_id: eve_id} = character) do
    # Run async to not block the SSO callback
    Task.start(fn ->
      character_eve_id = eve_id |> String.to_integer()

      case WandererApp.Esi.post_characters_affiliation([character_eve_id]) do
        {:ok, [affiliation_info]} when is_map(affiliation_info) ->
          new_corporation_id = Map.get(affiliation_info, "corporation_id")
          new_alliance_id = Map.get(affiliation_info, "alliance_id")

          # Check if corporation changed
          corporation_changed = character.corporation_id != new_corporation_id
          alliance_changed = character.alliance_id != new_alliance_id

          if corporation_changed or alliance_changed do
            update_affiliation_data(character_id, character, new_corporation_id, new_alliance_id)
          end

        {:error, error} ->
          Logger.warning(
            "[AuthController] Failed to fetch affiliation for character #{character_id}: #{inspect(error)}"
          )

        _ ->
          :ok
      end
    end)
  end

  defp update_character_affiliation(_character), do: :ok

  defp update_affiliation_data(character_id, character, corporation_id, alliance_id) do
    # Fetch corporation info
    corporation_update =
      case WandererApp.Esi.get_corporation_info(corporation_id) do
        {:ok, %{"name" => corp_name, "ticker" => corp_ticker}} ->
          %{
            corporation_id: corporation_id,
            corporation_name: corp_name,
            corporation_ticker: corp_ticker
          }

        _ ->
          %{corporation_id: corporation_id}
      end

    # Fetch alliance info if present
    alliance_update =
      case alliance_id do
        nil ->
          %{alliance_id: nil, alliance_name: nil, alliance_ticker: nil}

        _ ->
          case WandererApp.Esi.get_alliance_info(alliance_id) do
            {:ok, %{"name" => alliance_name, "ticker" => alliance_ticker}} ->
              %{
                alliance_id: alliance_id,
                alliance_name: alliance_name,
                alliance_ticker: alliance_ticker
              }

            _ ->
              %{alliance_id: alliance_id}
          end
      end

    full_update = Map.merge(corporation_update, alliance_update)

    # Update database
    case character.corporation_id != corporation_id do
      true ->
        {:ok, _} = WandererApp.Api.Character.update_corporation(character, corporation_update)

      false ->
        :ok
    end

    case character.alliance_id != alliance_id do
      true ->
        {:ok, _} = WandererApp.Api.Character.update_alliance(character, alliance_update)

      false ->
        :ok
    end

    # Update cache
    WandererApp.Character.update_character(character_id, full_update)

    Logger.info(
      "[AuthController] Updated affiliation for character #{character_id}: " <>
        "corp #{character.corporation_id} -> #{corporation_id}, " <>
        "alliance #{character.alliance_id} -> #{alliance_id}"
    )
  end
end
