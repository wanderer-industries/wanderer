defmodule WandererAppWeb.Plugs.CheckWebhooksDisabled do
  @moduledoc """
  Plug to check if webhooks are enabled.

  Returns 403 Forbidden if `WandererApp.Env.webhooks_enabled?/0` returns false.
  This is controlled via the WANDERER_WEBHOOKS_ENABLED environment variable.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not WandererApp.Env.webhooks_enabled?() do
      conn
      |> put_status(:forbidden)
      |> send_resp(403, "Webhooks are disabled on this server")
      |> halt()
    else
      conn
    end
  end
end
