defmodule WandererAppWeb.Plugs.CheckWebsocketDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not WandererApp.Env.websocket_events_enabled?() do
      conn
      |> send_resp(403, "WebSocket events are disabled")
      |> halt()
    else
      conn
    end
  end
end
