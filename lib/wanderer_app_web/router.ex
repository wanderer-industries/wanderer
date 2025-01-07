defmodule WandererAppWeb.Router do
  use WandererAppWeb, :router
  use ErrorTracker.Web, :router
  use Plug.ErrorHandler

  import PlugDynamic.Builder

  import WandererAppWeb.UserAuth,
    warn: false,
    only: [redirect_if_user_is_authenticated: 2]

  import WandererAppWeb.BasicAuth,
    warn: false,
    only: [admin_basic_auth: 2]

  @code_reloading Application.compile_env(
                    :wanderer_app,
                    [WandererAppWeb.Endpoint, :code_reloader],
                    false
                  )
  @frame_src if(@code_reloading, do: ~w('self'), else: ~w())
  @style_src ~w('self' 'unsafe-inline' https://fonts.googleapis.com)
  @img_src ~w('self' data: https://images.evetech.net https://web.ccpgamescdn.com https://images.ctfassets.net https://w.appzi.io)
  @font_src ~w('self' data: https://web.ccpgamescdn.com https://w.appzi.io)
  @script_src ~w('self' )

  pipeline :admin_bauth do
    plug :admin_basic_auth
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {WandererAppWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)

    dynamic_plug PlugContentSecurityPolicy, reevaluate: :first_usage do
      URI.default_port("wss", 443)
      URI.default_port("ws", 80)

      home_url = URI.parse(WandererAppWeb.Endpoint.url())

      ws_url =
        home_url
        |> Map.update!(:scheme, fn
          "http" -> "ws"
          "https" -> "wss"
        end)
        |> Map.put(:path, "")
        |> URI.to_string()

      directives = %{
        default_src: ~w('none'),
        script_src: [
          @script_src,
          ~w('unsafe-inline'),
          ~w(https://unpkg.com),
          ~w(https://cdn.jsdelivr.net),
          ~w(https://w.appzi.io),
          ~w(https://www.googletagmanager.com),
          ~w(https://cdnjs.cloudflare.com)
        ],
        style_src: @style_src,
        img_src: @img_src,
        font_src: @font_src,
        connect_src: [
          ws_url,
          ~w('self'),
          ~w(https://api.appzi.io),
          ~w(https://www.googletagmanager.com),
          ~w(https://www.google-analytics.com)
        ],
        media_src: ~w('none'),
        object_src: ~w('none'),
        child_src: ~w('none'),
        frame_src: [@frame_src],
        worker_src: ~w('none'),
        frame_ancestors: ~w('none'),
        form_action: ~w('self'),
        block_all_mixed_content: ~w(),
        sandbox:
          ~w(allow-forms allow-scripts allow-modals allow-same-origin allow-downloads allow-popups),
        base_uri: ~w('none'),
        manifest_src: ~w('self')
      }

      directives =
        case home_url do
          %URI{scheme: "http"} -> directives
          %URI{scheme: "https"} -> Map.put(directives, :upgrade_insecure_requests, ~w())
        end

      [
        directives: directives
      ]
    end

    plug WandererAppWeb.Plugs.SetUser
  end

  pipeline :blog do
    plug(:put_layout, html: {WandererAppWeb.Layouts, :blog})
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug WandererAppWeb.Plugs.CheckApiDisabled
  end

  pipeline :api_map do
    plug WandererAppWeb.Plugs.CheckMapApiKey
  end

  if not WandererApp.Env.public_api_disabled?() do
    scope "/api/map", WandererAppWeb do
      pipe_through [:api_map]
      pipe_through [:api]

      # GET /api/map/systems?map_id=... or ?slug=...
      get "/systems", APIController, :list_systems

      # GET /api/map/system-static-info?id=... plus either map_id=... or slug=...
      get "/system-static-info", APIController, :show_system_static

      # GET /api/map/system?id=... plus either map_id=... or slug=...
      get "/system", APIController, :show_system

      # GET /api/map/characters?map_id=... or slug=...
      get "/characters", APIController, :tracked_characters_with_info
    end
  end

scope "/api/common", WandererAppWeb do
  pipe_through [:api]

  # GET /api/common/system-static-info?id=...
  get "/system-static-info", APIController, :show_system_static

end

  scope "/", WandererAppWeb do
    pipe_through [:browser, :blog, :redirect_if_user_is_authenticated]

    get "/welcome", BlogController, :index
  end

  scope "/contacts", WandererAppWeb do
    pipe_through [:browser, :blog]

    get "/", BlogController, :contacts
  end

  scope "/changelog", WandererAppWeb do
    pipe_through [:browser, :blog]

    get "/", BlogController, :changelog
  end

  scope "/news", WandererAppWeb do
    pipe_through [:browser, :blog]

    get "/:slug", BlogController, :show
    get "/", BlogController, :list
  end

  scope "/license", WandererAppWeb do
    pipe_through [:browser, :blog]

    get "/", BlogController, :license
  end

  scope "/auth", WandererAppWeb do
    pipe_through :browser

    get "/signout", AuthController, :signout
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/admin", WandererAppWeb do
    pipe_through(:browser)
    pipe_through(:admin_bauth)

    live_session :admin,
      on_mount: [
        {WandererAppWeb.UserAuth, :ensure_authenticated},
        {WandererAppWeb.UserAuth, :ensure_admin},
        WandererAppWeb.Nav
      ] do
      live("/", AdminLive, :index)
    end

    error_tracker_dashboard("/errors",
      on_mount: [
        {WandererAppWeb.UserAuth, :ensure_authenticated},
        {WandererAppWeb.UserAuth, :ensure_admin}
      ]
    )
  end

  scope "/", WandererAppWeb do
    pipe_through(:browser)

    get "/", RedirectController, :redirect_authenticated
    get("/last", MapsController, :last)

    live_session :authenticated,
      on_mount: [
        {WandererAppWeb.UserAuth, :ensure_authenticated},
        WandererAppWeb.Nav
      ] do
      live("/access-lists/new", AccessListsLive, :create)
      live("/access-lists/:id/edit", AccessListsLive, :edit)
      live("/access-lists/:id/add-members", AccessListsLive, :add_members)
      live("/access-lists/:id", AccessListsLive, :members)
      live("/access-lists", AccessListsLive, :index)
      live("/coming-soon", ComingLive, :index)
      live("/tracking/:slug", CharactersTrackingLive, :characters)
      live("/tracking", CharactersTrackingLive, :index)
      live("/characters", CharactersLive, :index)
      live("/characters/authorize", CharactersLive, :authorize)
      live("/maps/new", MapsLive, :create)
      live("/maps/:slug/edit", MapsLive, :edit)
      live("/maps/:slug/settings", MapsLive, :settings)
      live("/maps", MapsLive, :index)
      live("/profile", ProfileLive, :index)
      live("/profile/deposit", ProfileLive, :deposit)
      live("/profile/subscribe", ProfileLive, :subscribe)
      live("/:slug/audit", MapAuditLive, :index)
      live("/:slug", MapLive, :index)
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wanderer_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      error_tracker_dashboard("/errors", as: :error_tracker_dev_dashboard)

      live_dashboard("/dashboard", metrics: WandererAppWeb.Telemetry)
    end
  end
end
