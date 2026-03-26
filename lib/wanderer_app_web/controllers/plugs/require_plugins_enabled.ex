defmodule WandererAppWeb.Plugs.RequirePluginsEnabled do
  @moduledoc """
  Plug that requires plugins to be enabled.

  Blocks access to plugin endpoints when plugins are disabled.
  Enable plugins by setting WANDERER_PLUGINS_ENABLED=true in your environment.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if not WandererApp.Env.plugins_enabled?() do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        403,
        Jason.encode!(%{
          error: "Plugins are disabled. Set WANDERER_PLUGINS_ENABLED=true to enable."
        })
      )
      |> halt()
    else
      conn
    end
  end
end
