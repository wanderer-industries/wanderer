defmodule WandererAppWeb.Plugs.CheckKillsDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not WandererApp.Env.wanderer_kills_service_enabled?() do
      conn
      |> send_resp(403, "Map kill feed is disabled")
      |> halt()
    else
      conn
    end
  end
end
