defmodule WandererAppWeb.Plugs.AssignMapOwner do
  import Plug.Conn

  alias WandererApp.Map.Operations

  def init(opts), do: opts

  def call(conn, _opts) do
    map_id = conn.assigns[:map_id]

    case Operations.get_owner_character_id(map_id) do
      {:ok, %{id: char_id, user_id: user_id}} ->
        conn
        |> assign(:owner_character_id, char_id)
        |> assign(:owner_user_id, user_id)

      _ ->
        conn
        |> assign(:owner_character_id, nil)
        |> assign(:owner_user_id, nil)
    end
  end
end
