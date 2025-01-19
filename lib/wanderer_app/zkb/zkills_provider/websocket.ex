defmodule WandererApp.Zkb.KillsProvider.Websocket do
  @moduledoc """
  Handles real-time kills from zKillboard WebSocket.
  Always fetches from ESI to get killmail_time, victim, attackers, etc.
  """

  require Logger
  alias WandererApp.Zkb.KillsProvider.Parser
  alias WandererApp.Esi

  @heartbeat_interval 1_000

  # Called by `KillsProvider.handle_connect`
  def handle_connect(_status, _headers, %{connected: _} = state) do
    Logger.info("[KillsProvider.Websocket] Connected => killstream")
    new_state = Map.put(state, :connected, true)
    handle_subscribe("killstream", new_state)
  end

  # Called by `KillsProvider.handle_in`
  def handle_in({:text, frame}, state) do
    partial = Jason.decode!(frame)

    parse_and_store_zkb_partial(partial)
    {:ok, state}
  end

  # Called by Fresh for control frames
  def handle_control({:pong, _msg}, state),
    do: {:ok, state}

  def handle_control({:ping, _}, state) do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
    {:ok, state}
  end

  # Called by Fresh for :info messages
  def handle_info(:heartbeat, state) do
    payload = Jason.encode!(%{"action" => "pong"})
    {:reply, {:text, payload}, state}
  end

  def handle_info(_other, state), do: {:ok, state}

  # Called on disconnect
  def handle_disconnect(code, reason, _old_state) do
    Logger.warning("[KillsProvider.Websocket] Disconnected => code=#{code}, reason=#{inspect(reason)} => reconnecting")
    :reconnect
  end

  # Called on errors
  def handle_error({err, _reason}, state) when err in [:encoding_failed, :casting_failed],
    do: {:ignore, state}

  def handle_error(_error, _state),
    do: :reconnect

  # Called on terminate
  def handle_terminate(reason, _state),
    do: Logger.warning("[KillsProvider.Websocket] Terminating => #{inspect(reason)}")

  defp handle_subscribe(channel, state) do
    payload = Jason.encode!(%{"action" => "sub", "channel" => channel})
    {:reply, {:text, payload}, state}
  end

  # The partial from zKillboard has killmail_id + zkb.hash, but no time/victim/attackers
  defp parse_and_store_zkb_partial(%{"killmail_id" => kill_id, "zkb" => %{"hash" => kill_hash}} = partial) do
    case Esi.get_killmail(kill_id, kill_hash) do
      {:ok, full_esi_data} ->
        # Merge partial zKB fields (like totalValue) onto ESI data
        enriched = Map.merge(full_esi_data, %{"zkb" => partial["zkb"]})
        Parser.parse_and_store_killmail(enriched)

      {:error, reason} ->
        Logger.warning("[KillsProvider:WS] ESI get_killmail failed => kill_id=#{kill_id}, reason=#{inspect(reason)}")
        :skip
    end
  end

  defp parse_and_store_zkb_partial(_),
    do: :skip
end
