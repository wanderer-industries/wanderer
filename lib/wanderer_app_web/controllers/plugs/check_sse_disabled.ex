defmodule WandererAppWeb.Plugs.CheckSseDisabled do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not WandererApp.Env.sse_enabled?() do
      conn
      |> put_status(:service_unavailable)
      |> send_resp(503, "Server-Sent Events are disabled on this server")
      |> halt()
    else
      conn
    end
  end
end
