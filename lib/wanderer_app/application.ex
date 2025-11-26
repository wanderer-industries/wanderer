defmodule WandererApp.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Skip test mocks setup - handled in test helper if needed

    # Core children that must always start
    core_children = [
      WandererApp.PromEx,
      WandererAppWeb.Telemetry,
      WandererApp.Vault,
      WandererApp.Repo,
      {Phoenix.PubSub, name: WandererApp.PubSub, adapter_name: Phoenix.PubSub.PG2},
      # Multiple Finch pools for different services to prevent connection pool exhaustion
      # ESI Character Tracking pool - high capacity for bulk character operations
      {
        Finch,
        name: WandererApp.Finch.ESI.CharacterTracking,
        pools: %{
          default: [
            size: Application.get_env(:wanderer_app, :finch_esi_character_pool_size, 100),
            count: Application.get_env(:wanderer_app, :finch_esi_character_pool_count, 4)
          ]
        }
      },
      # ESI General pool - standard capacity for general ESI operations
      {
        Finch,
        name: WandererApp.Finch.ESI.General,
        pools: %{
          default: [
            size: Application.get_env(:wanderer_app, :finch_esi_general_pool_size, 50),
            count: Application.get_env(:wanderer_app, :finch_esi_general_pool_count, 4)
          ]
        }
      },
      # Webhooks pool - isolated from ESI rate limits
      {
        Finch,
        name: WandererApp.Finch.Webhooks,
        pools: %{
          default: [
            size: Application.get_env(:wanderer_app, :finch_webhooks_pool_size, 25),
            count: Application.get_env(:wanderer_app, :finch_webhooks_pool_count, 2)
          ]
        }
      },
      # Default pool - everything else (email, license manager, etc.)
      {
        Finch,
        name: WandererApp.Finch,
        pools: %{
          default: [
            size: Application.get_env(:wanderer_app, :finch_default_pool_size, 25),
            count: Application.get_env(:wanderer_app, :finch_default_pool_count, 2)
          ]
        }
      },
      WandererApp.Cache,
      Supervisor.child_spec({Cachex, name: :api_cache, default_ttl: :timer.hours(1)},
        id: :api_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :esi_auth_cache}, id: :esi_auth_cache_worker),
      Supervisor.child_spec({Cachex, name: :system_static_info_cache},
        id: :system_static_info_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :ship_types_cache}, id: :ship_types_cache_worker),
      Supervisor.child_spec({Cachex, name: :character_cache}, id: :character_cache_worker),
      Supervisor.child_spec({Cachex, name: :acl_cache}, id: :acl_cache_worker),
      Supervisor.child_spec({Cachex, name: :map_cache}, id: :map_cache_worker),
      Supervisor.child_spec({Cachex, name: :map_pool_cache},
        id: :map_pool_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :map_state_cache}, id: :map_state_cache_worker),
      Supervisor.child_spec({Cachex, name: :character_state_cache},
        id: :character_state_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :tracked_characters},
        id: :tracked_characters_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :wanderer_app_cache},
        id: :wanderer_app_cache_worker
      ),
      {Registry, keys: :unique, name: WandererApp.Character.TrackerRegistry},
      {PartitionSupervisor,
       child_spec: DynamicSupervisor, name: WandererApp.Character.DynamicSupervisors},
      WandererAppWeb.PresenceGracePeriodManager,
      WandererAppWeb.Presence,
      WandererAppWeb.Endpoint
    ]

    # Children that should only start in non-test environments
    runtime_children =
      if Application.get_env(:wanderer_app, :environment) == :test do
        []
      else
        security_audit_children =
          if Application.get_env(:wanderer_app, WandererApp.SecurityAudit, [])
             |> Keyword.get(:async, false) do
            [WandererApp.SecurityAudit.AsyncProcessor]
          else
            []
          end

        [
          WandererApp.Esi.InitClientsTask,
          WandererApp.Scheduler,
          WandererApp.Server.ServerStatusTracker,
          WandererApp.Server.TheraDataFetcher,
          {WandererApp.Character.TrackerPoolSupervisor, []},
          {WandererApp.Map.MapPoolSupervisor, []},
          WandererApp.Character.TrackerManager,
          WandererApp.Map.Manager
        ] ++ security_audit_children
      end

    children =
      core_children ++
        runtime_children ++
        maybe_start_corp_wallet_tracker(WandererApp.Env.map_subscriptions_enabled?()) ++
        maybe_start_kills_services() ++
        maybe_start_external_events_services()

    opts = [strategy: :one_for_one, name: WandererApp.Supervisor]

    Supervisor.start_link(children, opts)
    |> case do
      {:ok, _pid} = ok ->
        # Attach telemetry handler for database pool monitoring
        # :telemetry.attach(
        #   "wanderer-db-pool-handler",
        #   [:wanderer_app, :repo, :query],
        #   &WandererApp.Tracker.handle_pool_query/4,
        #   nil
        # )

        ok

      {:error, info} = e ->
        Logger.error("Failed to start application: #{inspect(info)}")
        e
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    WandererAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_start_corp_wallet_tracker(true) do
    # Don't start corp wallet tracker in test environment
    if Application.get_env(:wanderer_app, :environment) == :test do
      []
    else
      [WandererApp.StartCorpWalletTrackerTask]
    end
  end

  defp maybe_start_corp_wallet_tracker(_), do: []

  defp maybe_start_kills_services do
    # Don't start kills services in test environment
    if Application.get_env(:wanderer_app, :environment) == :test do
      []
    else
      wanderer_kills_enabled =
        Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, false)

      if wanderer_kills_enabled in [true, "true"] do
        Logger.info("Starting WandererKills service integration...")

        [
          WandererApp.Kills.Supervisor,
          WandererApp.Map.ZkbDataFetcher
        ]
      else
        []
      end
    end
  end

  defp maybe_start_external_events_services do
    # Don't start external events in test environment
    if Application.get_env(:wanderer_app, :environment) == :test do
      []
    else
      external_events_config = Application.get_env(:wanderer_app, :external_events, [])
      sse_enabled = WandererApp.Env.sse_enabled?()
      webhooks_enabled = external_events_config[:webhooks_enabled] || false

      services = []

      # Always include MapEventRelay if any external events are enabled
      services =
        if sse_enabled || webhooks_enabled do
          Logger.info("Starting external events system...")
          [WandererApp.ExternalEvents.MapEventRelay | services]
        else
          services
        end

      # Add WebhookDispatcher if webhooks are enabled
      services =
        if webhooks_enabled do
          Logger.info("Starting webhook dispatcher...")
          [WandererApp.ExternalEvents.WebhookDispatcher | services]
        else
          services
        end

      # Add SseStreamManager if SSE is enabled
      services =
        if sse_enabled do
          Logger.info("Starting SSE stream manager...")
          [WandererApp.ExternalEvents.SseStreamManager | services]
        else
          services
        end

      Enum.reverse(services)
    end
  end
end
