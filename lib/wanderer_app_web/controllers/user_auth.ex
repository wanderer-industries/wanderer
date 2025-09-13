defmodule WandererAppWeb.UserAuth do
  @moduledoc false

  use WandererAppWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias Phoenix.LiveView

  alias WandererApp.Api.{User}

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = User.by_id!(user_id) |> Ash.load!(:characters)
        admins = WandererApp.Env.admins()

        user_role =
          case Enum.empty?(admins) or user.hash in admins do
            true ->
              :admin

            _ ->
              :user
          end

        new_socket =
          socket
          |> Phoenix.Component.assign_new(:current_user, fn ->
            user
          end)
          |> Phoenix.Component.assign_new(:current_user_role, fn ->
            user_role
          end)

        case new_socket.assigns.current_user do
          nil ->
            {:halt, redirect_require_login(socket)}

          %User{characters: characters} ->
            {:cont, new_socket}
        end

      %{} ->
        {:halt, redirect_require_login(socket)}
    end
  rescue
    _ -> {:halt, redirect_require_login(socket)}
  end

  def on_mount(:ensure_admin, _params, _session, socket) do
    case socket.assigns.current_user_role do
      :admin ->
        {:cont, socket}

      _ ->
        {:halt, redirect_not_admin(socket)}
    end
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    case user_id && WandererApp.Api.User.by_id(user_id, load: :characters) do
      {:ok, user} ->
        conn
        |> assign(:current_user, user)

      _ ->
        conn
        |> assign(:current_user, nil)
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/last")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/characters")
      |> halt()
    end
  end

  defp redirect_require_login(socket) do
    socket
    |> LiveView.redirect(to: ~p"/welcome")
  end

  defp redirect_not_admin(socket) do
    socket
    |> LiveView.redirect(to: ~p"/")
  end

  defp track_characters([]), do: :ok

  defp track_characters([%{id: character_id} | characters]) do
    :ok = WandererApp.Character.TrackerManager.start_tracking(character_id)
    track_characters(characters)
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    %{request_path: request_path, query_string: query_string} = conn
    return_to = if query_string == "", do: request_path, else: request_path <> "?" <> query_string
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_store_return_to(conn), do: conn
end
