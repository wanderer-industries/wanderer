defmodule WandererAppWeb.Plugs.CheckPluginApiKey do
  @moduledoc """
  Plug to authenticate plugin API requests using a per-plugin API key.

  Each plugin type has one server-wide API key set via environment variable.
  The bot provides this key as a Bearer token.
  """

  @behaviour Plug

  import Plug.Conn
  alias Plug.Crypto
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    plugin_name = conn.params["plugin_name"]

    with {:ok, _} <- valid_plugin?(plugin_name),
         {:ok, expected_key} <- WandererApp.Plugins.get_api_key(plugin_name),
         ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- Crypto.secure_compare(expected_key, token) do
      conn
      |> assign(:plugin_name, plugin_name)
    else
      false ->
        Logger.warning("Unauthorized: invalid token for plugin #{plugin_name}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized (invalid token)"}))
        |> halt()

      {:error, :not_a_plugin} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Unknown plugin: #{plugin_name}"}))
        |> halt()

      {:error, :no_api_key} ->
        Logger.warning("Plugin #{plugin_name} has no API key configured")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: "Plugin not configured on this server"}))
        |> halt()

      [] ->
        Logger.warning("Missing Bearer token for plugin API")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Missing or invalid Bearer token"}))
        |> halt()

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  defp valid_plugin?(name) do
    if WandererApp.Plugins.PluginRegistry.plugin_exists?(name) do
      {:ok, name}
    else
      {:error, :not_a_plugin}
    end
  end
end
