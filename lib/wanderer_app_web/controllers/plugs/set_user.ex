defmodule WandererAppWeb.Plugs.SetUser do
  @moduledoc false

  import Plug.Conn

  alias WandererApp.Api.User

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    case _load_user(user_id) do
      nil ->
        conn
        |> assign(:current_user, nil)
        |> assign(:current_user_role, :none)

      user ->
        admins = WandererApp.Env.admins()

        user_role =
          case Enum.empty?(admins) or user.hash in admins do
            true ->
              :admin

            _ ->
              :user
          end

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, user_role)
    end
  end

  defp _load_user(nil), do: nil

  defp _load_user(user_id) do
    case User.by_id(user_id, load: :characters) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end
end
