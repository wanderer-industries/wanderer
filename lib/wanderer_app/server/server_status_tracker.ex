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
    :retries
  ]

  @retries_count 3

  @initial_state %{
    players: 0,
    retries: @retries_count,
    server_version: "0",
    start_time: "0",
    vip: true
  }

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
          retries: retries
        } = state
      ) do
    Process.send_after(self(), :refresh_status, @refresh_interval)
    Task.async(fn -> get_server_status(retries) end)

    {:noreply, state}
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
        {:status, _get_status(result)}

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

  defp _get_status(%{
         "players" => 0,
         "server_version" => server_version,
         "start_time" => start_time,
         "vip" => _vip
       }) do
    %{players: 0, server_version: server_version, start_time: start_time, vip: true}
  end

  defp _get_status(%{
         "players" => players,
         "server_version" => server_version,
         "start_time" => start_time,
         "vip" => vip
       }) do
    %{players: players, server_version: server_version, start_time: start_time, vip: vip}
  end

  defp _get_status(%{
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
end
