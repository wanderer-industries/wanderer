defmodule WandererAppWeb.Plugs.CheckWebhooksDisabled do
  @moduledoc """
  Plug to check if webhooks are enabled.

  This plug blocks access to webhook management endpoints when webhooks are disabled.
  Enable webhooks by setting WANDERER_WEBHOOKS_ENABLED=true in your environment.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not WandererApp.Env.webhooks_enabled?() do
      conn
      |> send_resp(403, "Webhooks are disabled. Set WANDERER_WEBHOOKS_ENABLED=true to enable.")
      |> halt()
    else
      conn
    end
  end
end
