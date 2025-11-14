defmodule WandererApp.Server.ServerStatusTracker do
  @moduledoc false
  use GenServer

  require Logger

  @name :server_status_tracker

  defstruct [
    :players,
    :server_version,
    :start_time,
    :vip,
    :retries,
    :in_forced_downtime,
    :downtime_notified
  ]

  @retries_count 3

  @initial_state %{
    players: 0,
    retries: @retries_count,
    server_version: "0",
    start_time: "0",
    vip: true,
    in_forced_downtime: false,
    downtime_notified: false
  }

  # EVE Online daily downtime period (UTC/GMT)
  @downtime_start_hour 10
  @downtime_start_minute 58
  @downtime_end_hour 11
  @downtime_end_minute 2

  @refresh_interval :timer.minutes(1)

  @logger Application.compile_env(:wanderer_app, :logger)

  def start_link(opts \\ []), do: GenServer.start(__MODULE__, opts, name: @name)

  @impl true
  def init(_opts) do
    @logger.info("#{__MODULE__} started")

    {:ok, @initial_state, {:continue, :start}}
  end

  @impl true
  def terminate(_reason, _state), do: :ok

  @impl true
  def handle_call(:stop, _, state), do: {:stop, :normal, :ok, state}

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

  @impl true
  def handle_continue(:start, state) do
    Process.send_after(self(), :refresh_status, 100)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :refresh_status,
        %{
          retries: retries,
          in_forced_downtime: was_in_downtime
        } = state
      ) do
    Process.send_after(self(), :refresh_status, @refresh_interval)

    in_downtime = in_forced_downtime?()

    cond do
      # Entering downtime period - broadcast offline status immediately
      in_downtime and not was_in_downtime ->
        @logger.info("#{__MODULE__} entering forced downtime period (10:58-11:02 GMT)")

        downtime_status = %{
          players: 0,
          server_version: "downtime",
          start_time: DateTime.utc_now() |> DateTime.to_iso8601(),
          vip: true
        }

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "server_status",
          {:server_status, downtime_status}
        )

        {:noreply,
         %{state | in_forced_downtime: true, downtime_notified: true}
         |> Map.merge(downtime_status)}

      # Currently in downtime - skip API call
      in_downtime ->
        {:noreply, state}

      # Exiting downtime period - resume normal operations
      not in_downtime and was_in_downtime ->
        @logger.info("#{__MODULE__} exiting forced downtime period, resuming normal operations")
        Task.async(fn -> get_server_status(retries) end)
        {:noreply, %{state | in_forced_downtime: false, downtime_notified: false}}

      # Normal operation
      true ->
        Task.async(fn -> get_server_status(retries) end)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {ref, result},
        %{
          retries: retries
        } = state
      ) do
    Process.demonitor(ref, [:flush])

    case result do
      {:status, status} ->
        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "server_status",
          {:server_status, status}
        )

        {:noreply, state |> Map.merge(status)}

      :retry ->
        {:noreply, %{state | retries: retries - 1}}

      {:error, _error} ->
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_action, state),
    do: {:noreply, state}

  defp get_server_status(retries) do
    case WandererApp.Esi.get_server_status() do
      {:ok, result} ->
        {:status, extract_status(result)}

      {:error, :timeout} ->
        if retries > 0 do
          :retry
        else
          Logger.warning("#{__MODULE__} failed to refresh server status: :timeout")
          {:status, @initial_state}
        end

      {:error, error} ->
        if retries > 0 do
          :retry
        else
          Logger.warning("#{__MODULE__} failed to refresh server status: #{inspect(error)}")
          {:status, @initial_state}
        end

      _ ->
        {:error, :unknown}
    end
  end

  defp extract_status(%{
         "players" => 0,
         "server_version" => server_version,
         "start_time" => start_time,
         "vip" => _vip
       }) do
    %{players: 0, server_version: server_version, start_time: start_time, vip: true}
  end

  defp extract_status(%{
         "players" => players,
         "server_version" => server_version,
         "start_time" => start_time,
         "vip" => vip
       }) do
    %{players: players, server_version: server_version, start_time: start_time, vip: vip}
  end

  defp extract_status(%{
         "players" => players,
         "server_version" => server_version,
         "start_time" => start_time
       }) do
    %{
      players: players,
      server_version: server_version,
      start_time: start_time,
      vip: false
    }
  end

  # Checks if the current UTC time falls within the forced downtime period (10:58-11:02 GMT).
  defp in_forced_downtime? do
    now = DateTime.utc_now()
    current_hour = now.hour
    current_minute = now.minute

    # Convert times to minutes since midnight for easier comparison
    current_time_minutes = current_hour * 60 + current_minute
    downtime_start_minutes = @downtime_start_hour * 60 + @downtime_start_minute
    downtime_end_minutes = @downtime_end_hour * 60 + @downtime_end_minute

    current_time_minutes >= downtime_start_minutes and
      current_time_minutes < downtime_end_minutes
  end
end
