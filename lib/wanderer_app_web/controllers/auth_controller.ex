defmodule WandererAppWeb.AuthController do
  use WandererAppWeb, :controller
  plug Ueberauth

  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user} = _assigns} = conn, _params) do
    character_data = %{
      eve_id: "#{auth.info.email}",
      name: auth.info.name,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at,
      scopes: auth.credentials.scopes
    }

    %{
      "CharacterOwnerHash" => character_owner_hash
    } = auth.extra.raw_info.user

    {:ok, character} =
      case WandererApp.Api.Character.by_eve_id(character_data.eve_id) do
        {:ok, character} ->
          character_update = %{
            access_token: auth.credentials.token,
            refresh_token: auth.credentials.refresh_token,
            expires_at: auth.credentials.expires_at,
            scopes: auth.credentials.scopes
          }

          {:ok, character} =
            character
            |> WandererApp.Api.Character.update(character_update)

          WandererApp.Character.update_character(character.id, character_update)

          {:ok, character}

        {:error, _error} ->
          {:ok, character} = WandererApp.Api.Character.create(character_data)
          :telemetry.execute([:wanderer_app, :user, :character, :registered], %{count: 1})

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
    WandererApp.Api.Character.assign_user!(character, %{user_id: user_id})
  end

  def maybe_update_character_user_id(_character, _user_id), do: :ok
end
