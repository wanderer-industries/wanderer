defmodule WandererAppWeb.Plugs.CheckApiDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if WandererApp.Env.public_api_disabled?() do
      conn
      |> send_resp(403, "Public API is disabled")
      |> halt()
    else
      conn
    end
  end
end
