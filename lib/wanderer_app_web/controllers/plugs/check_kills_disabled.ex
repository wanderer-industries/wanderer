defmodule WandererAppWeb.Plugs.CheckKillsDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if WandererApp.Env.zkill_preload_disabled?() do
      conn
      |> send_resp(403, "Map kill feed is disabled")
      |> halt()
    else
      conn
    end
  end
end
