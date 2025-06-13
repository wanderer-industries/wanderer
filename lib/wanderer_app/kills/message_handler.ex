defmodule WandererApp.Kills.MessageHandler do
  @moduledoc """
  Handles killmail message processing and broadcasting.
  """

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  alias WandererApp.Kills.{Config, DataAdapter, Storage}
  alias WandererApp.Kills.Subscription.MapIntegration

  @spec process_killmail_update(map()) :: :ok
  def process_killmail_update(%{"system_id" => system_id, "killmails" => killmails} = payload) do
    # Log each kill received
    Enum.each(killmails, fn kill ->
      killmail_id = kill["killmail_id"] || "unknown"
      kill_system_id = kill["solar_system_id"] || kill["system_id"] || system_id

      @logger.debug(fn ->
        "[MessageHandler] Received kill: killmail_id=#{killmail_id}, system_id=#{kill_system_id}"
      end)
    end)

    valid_killmails =
      killmails
      |> Enum.filter(&is_map/1)
      |> Enum.with_index()
      |> Enum.map(fn {kill, index} ->
        # Log raw kill data
        @logger.debug(fn ->
          "[MessageHandler] Raw kill ##{index}: #{inspect(kill, pretty: true, limit: :infinity)}"
        end)

        # Adapt and log result
        case DataAdapter.adapt_kill_data(kill) do
          {:ok, adapted} ->
            @logger.debug(fn ->
              "[MessageHandler] Adapted kill ##{index}: #{inspect(adapted, pretty: true, limit: :infinity)}"
            end)

            {:ok, adapted}

          {:error, reason} ->
            @logger.warning("[MessageHandler] Failed to adapt kill ##{index}: #{inspect(reason)}")
            {:error, reason}
        end
      end)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    @logger.debug(fn ->
      "[MessageHandler] Valid killmails after adaptation: #{length(valid_killmails)}"
    end)

    if valid_killmails != [] do
      ttl = Config.killmail_ttl()
      Storage.store_killmails(system_id, valid_killmails, ttl)
      Storage.update_kill_count(system_id, length(valid_killmails), ttl)
      broadcast_killmails(system_id, valid_killmails, payload)
    end

    :ok
  end

  def process_killmail_update(payload) do
    @logger.warning("[MessageHandler] Invalid killmail payload: #{inspect(payload)}")
    :ok
  end

  @spec process_kill_count_update(map()) :: :ok
  def process_kill_count_update(%{"system_id" => system_id, "count" => count} = payload) do
    Storage.store_kill_count(system_id, count)
    broadcast_kill_count(system_id, payload)
    :ok
  end

  def process_kill_count_update(payload) do
    @logger.warning("[MessageHandler] Invalid kill count payload: #{inspect(payload)}")
    :ok
  end

  defp broadcast_kill_count(system_id, payload) do
    case MapIntegration.broadcast_kill_to_maps(%{
           "solar_system_id" => system_id,
           "count" => payload["count"],
           "type" => :kill_count
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        @logger.warning("[MessageHandler] Failed to broadcast kill count: #{inspect(reason)}")
        :ok
    end
  end

  defp broadcast_killmails(system_id, killmails, payload) do
    case MapIntegration.broadcast_kill_to_maps(%{
           "solar_system_id" => system_id,
           "killmails" => killmails,
           "timestamp" => payload["timestamp"],
           "type" => :killmail_update
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        @logger.warning("[MessageHandler] Failed to broadcast killmails: #{inspect(reason)}")
        :ok
    end
  end
end
