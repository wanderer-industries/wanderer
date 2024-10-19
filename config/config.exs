# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :wanderer_app, WandererApp.Cache,
  # When using :shards as backend
  # backend: :shards,
  # GC interval for pushing new generation: 12 hrs
  gc_interval: :timer.hours(12),
  # Max 1 million entries in cache
  max_size: 1_000_000,
  # Max 2 GB of memory
  allocated_memory: 2_000_000_000,
  # GC min timeout: 10 sec
  gc_cleanup_min_timeout: :timer.seconds(10),
  # GC max timeout: 10 min
  gc_cleanup_max_timeout: :timer.minutes(10)

config :wanderer_app,
  ecto_repos: [WandererApp.Repo],
  ash_domains: [WandererApp.Api],
  generators: [timestamp_type: :utc_datetime],
  ddrt: DDRT,
  logger: Logger,
  pubsub_client: Phoenix.PubSub

config :wanderer_app, WandererAppWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: WandererAppWeb.ErrorHTML, json: WandererAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WandererApp.PubSub,
  live_view: [signing_salt: "LjxzzFQ1"]

config :ueberauth, Ueberauth,
  providers: [
    eve:
      {WandererApp.Ueberauth.Strategy.Eve,
       [
         default_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1",
         wallet_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1 esi-wallet.read_character_wallet.v1",
         admin_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1 esi-wallet.read_character_wallet.v1 esi-wallet.read_corporation_wallets.v1 esi-mail.send_mail.v1",
         callback_path: "/auth/eve/callback"
       ]}
  ]

config :wanderer_app, WandererApp.Mailer, adapter: Swoosh.Adapters.Local

config :dart_sass, :version, "1.54.5"

config :tailwind, :version, "3.2.7"

config :wanderer_app, WandererApp.PromEx, manual_metrics_start_delay: :no_delay

config :wanderer_app,
  grafana_datasource_id: "wanderer"

config :phoenix_ddos,
  protections: [
    # ip rate limit
    {PhoenixDDoS.IpRateLimit, allowed: 500, period: {2, :minutes}},
    {PhoenixDDoS.IpRateLimit, allowed: 10_000, period: {1, :hour}},
    # ip rate limit on specific request_path
    {PhoenixDDoS.IpRateLimitPerRequestPath,
     request_paths: ["/auth/eve"], allowed: 20, period: {1, :minute}}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :module, :function, :line, :request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :error_tracker,
  repo: WandererApp.Repo,
  otp_app: :wanderer_app

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/wanderer-industries/wanderer",
  types: [
    # Makes an allowed commit type called `tidbit` that is not
    # shown in the changelog
    tidbit: [
      hidden?: true
    ],
    # Makes an allowed commit type called `important` that gets
    # a section in the changelog with the header "Important Changes"
    important: [
      header: "Important Changes"
    ]
  ],
  tags: [
    # Only add commits to the changelog that has the "backend" tag
    allowed: ["feat", "fix", "docs"],
    # Filter out or not commits that don't contain tags
    allow_untagged?: true
  ],
  # Instructs the tool to manage your mix version in your `mix.exs` file
  # See below for more information
  manage_mix_version?: true,
  # Instructs the tool to manage the version in your README.md
  # Pass in `true` to use `"README.md"` or a string to customize
  manage_readme_version: "README.md",
  version_tag_prefix: "v"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
