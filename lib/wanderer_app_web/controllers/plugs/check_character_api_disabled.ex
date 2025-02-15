defmodule WandererAppWeb.Plugs.CheckCharacterApiDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if WandererApp.Env.character_api_disabled?() do
      conn
      |> send_resp(403, "Character API is disabled")
      |> halt()
    else
      conn
    end
  end
end
