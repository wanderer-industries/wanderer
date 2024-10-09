defmodule WandererApp.Zkb.KillsProvider do
  @moduledoc false
  use Fresh

  defstruct [:connected]

  require Logger

  @heartbeat_interval 1_000

  def handle_connect(_status, _headers, state) do
    Logger.debug(fn ->
      "#{__MODULE__}: connected to kills stream"
    end)

    handle_subscribe("killstream", %__MODULE__{state | connected: true})
  end

  def handle_in({:text, frame}, state) do
    frame
    |> Jason.decode!()
    |> handle_websocket(state)
  end

  def handle_control({:ping, _message}, state) do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
    {:ok, state}
  end

  def handle_control(_event, state) do
    {:ok, state}
  end

  def handle_info(:heartbeat, state) do
    payload =
      Jason.encode!(%{
        "action" => "pong"
      })

    {:reply, {:text, payload}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  def handle_info(_message, _ws, state) do
    {:ok, state}
  end

  defp handle_subscribe(channel, state) do
    Logger.debug(fn ->
      "#{__MODULE__} subscribe: #{inspect(channel, pretty: true)}"
    end)

    payload =
      Jason.encode!(%{
        "action" => "sub",
        "channel" => channel
      })

    {:reply, {:text, payload}, state}
  end

  defp handle_websocket(message, state) do
    case message |> parse_message() do
      nil ->
        {:ok, state}

      %{solar_system_id: solar_system_id, kill_time: kill_time} = _message ->
        case DateTime.diff(DateTime.utc_now(), kill_time, :hour) do
          0 ->
            WandererApp.Cache.incr("zkb_kills_#{solar_system_id}", 1,
              default: 0,
              ttl: :timer.hours(1)
            )

          _ ->
            :ok
        end
    end

    {:ok, state}
  end

  def handle_disconnect(1002, reason, _state) do
    Logger.warning(fn ->
      "Connection to socket lost by #{inspect(reason, pretty: true)}; reconnecting..."
    end)

    :reconnect
  end

  def handle_disconnect(_code, reason, _state) do
    Logger.warning(fn ->
      "Connection to socket lost by #{inspect(reason, pretty: true)}; closing..."
    end)

    :reconnect
  end

  def handle_error({error, _reason}, state)
      when error in [:encoding_failed, :casting_failed],
      do: {:ignore, state}

  def handle_error(_error, _state), do: :reconnect

  def handle_terminate(reason, _state) do
    Logger.warning(fn -> "Terminating client process with reason : #{inspect(reason)}" end)
  end

  defp parse_message(
         %{
           "solar_system_id" => solar_system_id,
           "killmail_time" => killmail_time
         } = _message
       ) do
    {:ok, kill_time, _} = DateTime.from_iso8601(killmail_time)

    %{
      solar_system_id: solar_system_id,
      kill_time: kill_time
    }
  end

  defp parse_message(_message), do: nil
end
