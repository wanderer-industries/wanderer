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

  # import WandererAppWeb.Plugs.LicenseAuth,
  #   warn: false,
  #   only: [authenticate_lm: 2, authenticate_license: 2]

  @code_reloading Application.compile_env(
                    :wanderer_app,
                    [WandererAppWeb.Endpoint, :code_reloader],
                    false
                  )
  @frame_src_values if(@code_reloading, do: ["'self'"], else: [])

  # Define style sources individually to ensure proper spacing
  @style_src_values [
    "'self'",
    "'unsafe-inline'",
    "https://fonts.googleapis.com",
    "https://cdn.jsdelivr.net/npm/",
    "https://cdnjs.cloudflare.com/ajax/libs/"
  ]

  # Define image sources individually to ensure proper spacing
  @img_src_values [
    "'self'",
    "data:",
    "https://images.evetech.net",
    "https://web.ccpgamescdn.com",
    "https://images.ctfassets.net",
    "https://w.appzi.io"
  ]

  # Define font sources individually to ensure proper spacing
  @font_src_values [
    "'self'",
    "https://fonts.gstatic.com",
    "data:",
    "https://web.ccpgamescdn.com",
    "https://w.appzi.io"
  ]

  # Define script sources individually to ensure proper spacing
  @script_src_values [
    "'self'",
    "'unsafe-inline'",
    "https://cdn.jsdelivr.net/npm/",
    "https://cdnjs.cloudflare.com/ajax/libs/",
    "https://unpkg.com",
    "https://cdn.jsdelivr.net",
    "https://w.appzi.io",
    "https://www.googletagmanager.com",
    "https://cdnjs.cloudflare.com"
  ]

  # Define connect sources individually to ensure proper spacing
  @connect_src_values [
    "'self'",
    "https://api.appzi.io",
    "https://www.googletagmanager.com",
    "https://www.google-analytics.com"
  ]

  # Define sandbox values individually to ensure proper spacing
  @sandbox_values [
    "allow-forms",
    "allow-scripts",
    "allow-modals",
    "allow-same-origin",
    "allow-downloads",
    "allow-popups"
  ]

  pipeline :admin_bauth do
    plug :admin_basic_auth
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WandererAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

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

      # Get the HTTP URL from home_url
      http_url = URI.to_string(home_url)

      # Only add script-src-elem when in development mode
      script_src_elem =
        if(@code_reloading,
          do: @script_src_values ++ [ws_url, http_url],
          else: @script_src_values
        )

      directives = %{
        default_src: ~w('none'),
        script_src: @script_src_values ++ [ws_url],
        style_src: @style_src_values,
        img_src: @img_src_values,
        font_src: @font_src_values,
        connect_src: @connect_src_values ++ [ws_url],
        media_src: ~w('none'),
        object_src: ~w('none'),
        child_src: ~w('none'),
        frame_src: @frame_src_values,
        worker_src: ~w('none'),
        frame_ancestors: ~w('none'),
        form_action: ~w('self'),
        block_all_mixed_content: ~w(),
        sandbox: @sandbox_values,
        base_uri: ~w('none'),
        manifest_src: ~w('self')
      }

      # Only add script-src-elem to directives when in development mode
      directives = Map.put(directives, :script_src_elem, script_src_elem)

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
    plug :put_layout, html: {WandererAppWeb.Layouts, :blog}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug WandererAppWeb.Plugs.CheckApiDisabled
  end

  pipeline :api_map do
    plug WandererAppWeb.Plugs.CheckMapApiKey
    plug WandererAppWeb.Plugs.CheckMapSubscription
  end

  pipeline :api_kills do
    plug WandererAppWeb.Plugs.CheckApiDisabled
  end

  pipeline :api_character do
    plug WandererAppWeb.Plugs.CheckCharacterApiDisabled
  end

  pipeline :api_acl do
    plug WandererAppWeb.Plugs.CheckAclApiKey
  end

  pipeline :api_spec do
    plug OpenApiSpex.Plug.PutApiSpec,
      otp_app: :wanderer_app,
      module: WandererAppWeb.ApiSpec
  end

  # pipeline :api_license_management do
  #   plug :authenticate_lm
  # end

  # pipeline :api_license_validation do
  #   plug :authenticate_license
  # end

  scope "/api/map/systems-kills", WandererAppWeb do
    pipe_through [:api, :api_map, :api_kills]

    get "/", MapAPIController, :list_systems_kills
  end

  scope "/api/map", WandererAppWeb do
    pipe_through [:api, :api_map]
    get "/audit", MapAuditAPIController, :index
    # Deprecated routes - use /api/maps/:map_identifier/systems instead
    get "/systems", MapSystemAPIController, :list_systems
    get "/system", MapSystemAPIController, :show_system
    get "/connections", MapSystemAPIController, :list_all_connections
    get "/characters", MapAPIController, :list_tracked_characters
    get "/structure-timers", MapAPIController, :show_structure_timers
    get "/character-activity", MapAPIController, :character_activity
    get "/user_characters", MapAPIController, :user_characters

    get "/acls", MapAccessListAPIController, :index
    post "/acls", MapAccessListAPIController, :create
  end

  #
  # Unified RESTful routes for systems & connections by slug or ID
  #
  scope "/api/maps/:map_identifier", WandererAppWeb do
    pipe_through [:api, :api_map]

    patch "/connections", MapConnectionAPIController, :update
    delete "/connections", MapConnectionAPIController, :delete
    delete "/systems", MapSystemAPIController, :delete
    resources "/systems", MapSystemAPIController, only: [:index, :show, :create, :update, :delete]
    resources "/connections", MapConnectionAPIController, only: [:index, :show, :create, :update, :delete], param: "id"
  end



  #
  # Other API routes
  #
  scope "/api/characters", WandererAppWeb do
    pipe_through [:api, :api_character]
    get "/", CharactersAPIController, :index
  end

  scope "/api/acls", WandererAppWeb do
    pipe_through [:api, :api_acl]

    get "/:id", MapAccessListAPIController, :show
    put "/:id", MapAccessListAPIController, :update
    post "/:acl_id/members", AccessListMemberAPIController, :create
    put "/:acl_id/members/:member_id", AccessListMemberAPIController, :update_role
    delete "/:acl_id/members/:member_id", AccessListMemberAPIController, :delete
  end

  scope "/api/common", WandererAppWeb do
    pipe_through [:api]
    get "/system-static-info", CommonAPIController, :show_system_static
  end

  scope "/api" do
    pipe_through [:browser, :api, :api_spec]
    get "/openapi", OpenApiSpex.Plug.RenderSpec, :show
  end

  # scope "/api/licenses", WandererAppWeb do
  #   pipe_through [:api, :api_license_management]

  #   post "/", LicenseApiController, :create
  #   put "/:id/validity", LicenseApiController, :update_validity
  #   put "/:id/expiration", LicenseApiController, :update_expiration
  #   get "/map/:map_id", LicenseApiController, :get_by_map_id
  # end

  # scope "/api/license", WandererAppWeb do
  #   pipe_through [:api, :api_license_validation]

  #   get "/validate", LicenseApiController, :validate
  # end

  #
  # Browser / blog stuff
  #
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

  scope "/swaggerui" do
    pipe_through [:browser, :api, :api_spec]

    get "/", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/openapi",
      title: "WandererApp API Docs",
      css_urls: [
        # Standard Swagger UI CSS
        "https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.5.0/swagger-ui.min.css",
        # Material theme from swagger-ui-themes (v3.x):
        "https://cdn.jsdelivr.net/npm/swagger-ui-themes@3.0.0/themes/3.x/theme-material.css"
      ],
      js_urls: [
        # We need both main JS & standalone preset for full styling
        "https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.5.0/swagger-ui-bundle.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.5.0/swagger-ui-standalone-preset.min.js"
      ],
      swagger_ui_config: %{
        "docExpansion" => "none",
        "deepLinking" => true
      }
  end

  #
  # Auth
  #
  scope "/auth", WandererAppWeb do
    pipe_through :browser
    get "/signout", AuthController, :signout
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  #
  # Admin
  #
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

  #
  # Additional routes / Live sessions
  #
  scope "/", WandererAppWeb do
    pipe_through(:browser)

    get "/", RedirectController, :redirect_authenticated
    get "/last", MapsController, :last

    live_session :authenticated,
      on_mount: [
        {WandererAppWeb.UserAuth, :ensure_authenticated},
        WandererAppWeb.Nav
      ] do
      live "/access-lists/new", AccessListsLive, :create
      live "/access-lists/:id/edit", AccessListsLive, :edit
      live "/access-lists/:id/add-members", AccessListsLive, :add_members
      live "/access-lists/:id", AccessListsLive, :members
      live "/access-lists", AccessListsLive, :index

      live "/coming-soon", ComingLive, :index
      live "/tracking/:slug", CharactersTrackingLive, :characters
      live "/tracking", CharactersTrackingLive, :index
      live "/characters", CharactersLive, :index
      live "/characters/authorize", CharactersLive, :authorize
      live "/maps/new", MapsLive, :create
      live "/maps/:slug/edit", MapsLive, :edit
      live "/maps/:slug/settings", MapsLive, :settings
      live "/maps", MapsLive, :index
      live "/profile", ProfileLive, :index
      live "/profile/deposit", ProfileLive, :deposit
      live "/profile/subscribe", ProfileLive, :subscribe
      live "/:slug/audit", MapAuditLive, :index
      live "/:slug/characters", MapCharactersLive, :index
      live "/:slug", MapLive, :index
    end
  end

  if Application.compile_env(:wanderer_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)
      error_tracker_dashboard("/errors", as: :error_tracker_dev_dashboard)
      live_dashboard("/dashboard", metrics: WandererAppWeb.Telemetry)
    end
  end
end
