defmodule WandererAppWeb.Endpoint do
  use Phoenix.Endpoint,
    otp_app: :wanderer_app

  import PlugDynamic.Builder

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_wanderer_app_key",
    signing_salt: "bMq3QgFG",
    same_site: "Lax",
    max_age: 24 * 60 * 60 * 180
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [compress: true, connect_info: [session: @session_options]]

  plug PhoenixDDoS

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :wanderer_app,
    gzip: false,
    only: WandererAppWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :wanderer_app
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug PromEx.Plug, prom_ex_module: WandererApp.PromEx
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  dynamic_plug Plug.Session, reevaluate: :first_usage do
    :wanderer_app
    |> Application.fetch_env!(WandererAppWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:scheme)
    |> case do
      "https" -> @session_options ++ [secure: true]
      _other -> @session_options
    end
  end

  plug WandererAppWeb.Router
end
