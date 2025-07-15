defmodule WandererApp.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children =
      [
        WandererApp.PromEx,
        WandererAppWeb.Telemetry,
        WandererApp.Vault,
        WandererApp.Repo,
        {Phoenix.PubSub, name: WandererApp.PubSub, adapter_name: Phoenix.PubSub.PG2},
        {
          Finch,
          name: WandererApp.Finch,
          pools: %{
            default: [
              # number of connections per pool
              size: 50,
              # number of pools (so total 50 connections)
              count: 4
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
        Supervisor.child_spec({Cachex, name: :map_cache}, id: :map_cache_worker),
        Supervisor.child_spec({Cachex, name: :character_state_cache},
          id: :character_state_cache_worker
        ),
        Supervisor.child_spec({Cachex, name: :tracked_characters},
          id: :tracked_characters_cache_worker
        ),
        WandererApp.Esi.InitClientsTask,
        WandererApp.Scheduler,
        {Registry, keys: :unique, name: WandererApp.MapRegistry},
        {Registry, keys: :unique, name: WandererApp.Character.TrackerRegistry},
        {PartitionSupervisor,
         child_spec: DynamicSupervisor, name: WandererApp.Map.DynamicSupervisors},
        {PartitionSupervisor,
         child_spec: DynamicSupervisor, name: WandererApp.Character.DynamicSupervisors},
        WandererApp.Server.ServerStatusTracker,
        WandererApp.Server.TheraDataFetcher,
        {WandererApp.Character.TrackerPoolSupervisor, []},
        WandererApp.Character.TrackerManager,
        WandererApp.Map.Manager,
        WandererAppWeb.Presence,
        WandererAppWeb.Endpoint
      ] ++
        maybe_start_corp_wallet_tracker(WandererApp.Env.map_subscriptions_enabled?()) ++
        maybe_start_kills_services()

    opts = [strategy: :one_for_one, name: WandererApp.Supervisor]

    Supervisor.start_link(children, opts)
    |> case do
      {:ok, _pid} = ok ->
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

  defp maybe_start_corp_wallet_tracker(true),
    do: [
      WandererApp.StartCorpWalletTrackerTask
    ]

  defp maybe_start_corp_wallet_tracker(_),
    do: []

  defp maybe_start_kills_services do
    wanderer_kills_enabled =
      Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, false)

    if wanderer_kills_enabled in [true, true, "true"] do
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
