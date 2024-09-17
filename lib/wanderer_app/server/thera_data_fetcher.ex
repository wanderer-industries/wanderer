defmodule WandererApp.Server.TheraDataFetcher do
  @moduledoc false
  use GenServer

  require Logger

  @name :thera_data_fetcher

  defstruct [
    :retries_count,
    :restart_timeout
  ]

  @eve_scout_base_url "https://api.eve-scout.com/v2/public"
  @refresh_timeout :timer.minutes(1)

  @initial_state %{
    retries_count: 5,
    restart_timeout: @refresh_timeout
  }

  def get_chain_pairs(params) do
    case WandererApp.Cache.get(@name) do
      nil ->
        {:ok, []}

      data ->
        {:ok,
         data
         |> Enum.filter(fn item -> _is_filtered(item, params) end)
         |> Enum.map(fn item ->
           %{
             first: item.source_solar_system_id,
             second: item.destination_solar_system_id
           }
         end)}
    end
  end

  defp _is_filtered(%{ship_size_type: 0}, %{
         include_frig: false
       }),
       do: false

  defp _is_filtered(%{time_status: 1}, %{
         include_eol: false
       }),
       do: false

  defp _is_filtered(%{time_status: 2}, %{
         include_mass_crit: false
       }),
       do: false

  defp _is_filtered(_, _), do: true

  def start_link(opts \\ []) do
    GenServer.start(__MODULE__, opts, name: @name)
  end

  @impl true
  def init(_opts) do
    Logger.info("#{__MODULE__} started")

    {:ok, @initial_state, {:continue, :start}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  @impl true
  def handle_call(:stop, _, state), do: {:stop, :normal, :ok, state}

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

  @impl true
  def handle_continue(:start, state) do
    Process.send_after(self(), :refresh_data, 500)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :refresh_data,
        state
      ) do
    Task.async(fn -> load_data() end)
    Process.send_after(self(), :refresh_data, @refresh_timeout)

    {:noreply, state}
  end

  @impl true
  def handle_info({ref, result}, state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, data} ->
        _cache_items(data)
        {:noreply, state}

      _ ->
        Logger.error("#{__MODULE__} failed to load data")
        {:noreply, state}
    end
  end

  def handle_info(_action, state),
    do: {:noreply, state}

  defp load_data() do
    case Req.get("#{@eve_scout_base_url}/signatures", params: [system_name: "thera"]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body |> _get_infos()}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Request failed"}
    end
  end

  defp _get_infos(data) do
    data
    |> Enum.map(&_get_info/1)
  end

  defp _get_info(%{
         "in_system_id" => in_system_id,
         "max_ship_size" => max_ship_size,
         "out_system_id" => out_system_id,
         "remaining_hours" => remaining_hours
       }) do
    %{
      source_solar_system_id: in_system_id,
      destination_solar_system_id: out_system_id,
      mass_status: 0,
      time_status: _get_time_status(remaining_hours),
      ship_size_type: _get_ship_size(max_ship_size)
    }
  end

  defp _get_ship_size("small"), do: 0
  defp _get_ship_size("medium"), do: 1
  defp _get_ship_size("large"), do: 1
  defp _get_ship_size("xlarge"), do: 2
  defp _get_ship_size(_), do: 1

  defp _get_time_status(remaining_hours) when remaining_hours < 2, do: 0
  defp _get_time_status(_), do: 1

  defp _cache_items([]), do: WandererApp.Cache.put(@name, [])

  defp _cache_items(items), do: WandererApp.Cache.put(@name, items)
end
