defmodule WandererApp.Map.LayoutScheduler do
  @moduledoc false

  use GenServer

  require Logger

  @debounce_ms 200

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def schedule(map_id) when is_binary(map_id) do
    GenServer.cast(__MODULE__, {:schedule, map_id})
  catch
    :exit, _reason -> :ok
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:schedule, map_id}, state) do
    entry = Map.get(state, map_id, %{timer: nil, monitor: nil, dirty: false})

    if entry.monitor do
      {:noreply, Map.put(state, map_id, %{entry | dirty: true})}
    else
      if entry.timer, do: Process.cancel_timer(entry.timer)
      timer = Process.send_after(self(), {:run, map_id}, @debounce_ms)
      {:noreply, Map.put(state, map_id, %{entry | timer: timer})}
    end
  end

  @impl true
  def handle_info({:run, map_id}, state) do
    entry = Map.fetch!(state, map_id)

    if layout_enabled?(map_id) do
      {_pid, monitor} = spawn_monitor(fn -> run_layout(map_id) end)
      {:noreply, Map.put(state, map_id, %{entry | timer: nil, monitor: monitor, dirty: false})}
    else
      {:noreply, Map.delete(state, map_id)}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Enum.find(state, fn {_map_id, entry} -> entry.monitor == monitor end) do
      {map_id, %{dirty: true} = entry} ->
        timer = Process.send_after(self(), {:run, map_id}, @debounce_ms)
        {:noreply, Map.put(state, map_id, %{entry | timer: timer, monitor: nil, dirty: false})}

      {map_id, _entry} ->
        {:noreply, Map.delete(state, map_id)}

      nil ->
        {:noreply, state}
    end
  end

  defp layout_enabled?(map_id) do
    WandererApp.Env.layout_service_enabled?() and
      WandererApp.LayoutSettings.get(map_id)["enabled"] == true
  end

  defp run_layout(map_id) do
    settings = WandererApp.LayoutSettings.get(map_id)

    case WandererApp.Map.Layout.run(map_id, settings) do
      {:ok, _result} -> :ok
      {:error, reason} -> Logger.warning("Automatic map layout failed: #{inspect(reason)}")
    end
  rescue
    error -> Logger.warning("Automatic map layout crashed: #{Exception.message(error)}")
  end
end
