defmodule WandererApp.Map.GarbageCollector do
  @moduledoc """
  Daily cleanup of map data that is only useful for a limited time:
  chain passages and system signatures.

  The jobs are scheduled in `config/runtime.exs` under `WandererApp.Scheduler`.
  """

  require Logger
  require Ash.Query

  @logger Application.compile_env(:wanderer_app, :logger)
  @seconds_per_day 24 * 60 * 60

  @doc """
  Deletes chain passages whose `updated_at` is older than
  `WandererApp.Env.map_chain_passages_retention_days/0` days
  (`WANDERER_MAP_CHAIN_PASSAGES_RETENTION_DAYS`, default 7).
  """
  def cleanup_chain_passages() do
    retention_days = WandererApp.Env.map_chain_passages_retention_days()

    Logger.info("Start cleanup map chain passages older than #{retention_days} days...")

    WandererApp.Api.MapChainPassages
    |> Ash.Query.filter(
      updated_at: [less_than: get_cutoff_time(retention_days * @seconds_per_day)]
    )
    |> Ash.bulk_destroy!(:destroy, %{}, batch_size: 100)

    @logger.info(fn -> "All map chain passages processed" end)

    :ok
  end

  @doc """
  Deletes system signatures whose `updated_at` is older than
  `WandererApp.Env.map_system_signatures_retention_days/0` days
  (`WANDERER_MAP_SYSTEM_SIGNATURES_RETENTION_DAYS`, default 14).
  """
  def cleanup_system_signatures() do
    retention_days = WandererApp.Env.map_system_signatures_retention_days()

    Logger.info("Start cleanup map system signatures older than #{retention_days} days...")

    WandererApp.Api.MapSystemSignature
    |> Ash.Query.filter(
      updated_at: [less_than: get_cutoff_time(retention_days * @seconds_per_day)]
    )
    |> Ash.bulk_destroy!(:destroy, %{}, batch_size: 100)

    @logger.info(fn -> "All map system signatures processed" end)

    :ok
  end

  defp get_cutoff_time(seconds), do: DateTime.utc_now() |> DateTime.add(-seconds, :second)
end
