defmodule WandererApp.Character.TrackerManager do
  @moduledoc """
  Manage character trackers
  """
  use GenServer

  require Logger

  alias WandererApp.GenImpl
  alias WandererApp.Character.TrackerManager.Impl

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_tracking(character_id, opts \\ []),
    do: GenServer.cast(__MODULE__, {&Impl.start_tracking/3, [character_id, opts]})

  def stop_tracking(character_id),
    do: GenServer.cast(__MODULE__, {&Impl.stop_tracking/2, [character_id]})

  def get_characters(opts \\ []),
    do: GenServer.call(__MODULE__, {&Impl.get_characters/2, [opts]})

  def update_track_settings(character_id, track_settings),
    do:
      GenServer.cast(__MODULE__, {&Impl.update_track_settings/3, [character_id, track_settings]})

  @impl true
  def init(args) do
    Logger.info("#{__MODULE__} started")

    {:ok, Impl.init(args), {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state), do: {:noreply, state |> Impl.start()}

  @impl true
  def terminate(_reason, _state), do: :ok

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

  @impl true
  def handle_call(:stop, _, state), do: {:stop, :normal, :ok, state}

  @impl true
  def handle_call(
        {impl_function, args},
        _from,
        state
      )
      when is_function(impl_function),
      do: GenImpl.apply_call(impl_function, state, args)

  @impl true
  def handle_cast({impl_function, args}, state)
      when is_function(impl_function) do
    case GenImpl.apply_call(impl_function, state, args) do
      {:reply, _return, updated_state} ->
        {:noreply, updated_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(event, state), do: {:noreply, Impl.handle_info(event, state)}

  def start_transaction_tracker(character_id) do
    case DynamicSupervisor.start_child(
           {:via, PartitionSupervisor, {WandererApp.Character.DynamicSupervisors, self()}},
           {WandererApp.Character.TransactionsTrackerSupervisor, character_id: character_id}
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error,
       {:shutdown,
        {:failed_to_start_child, WandererApp.Character.TransactionsTracker,
         {:already_started, pid}}}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def stop_transaction_tracker(character_id) do
    case WandererApp.Character.TransactionsTracker.pid(character_id) do
      pid when is_pid(pid) ->
        GenServer.call(pid, :stop)

      nil ->
        :ok
    end
  end
end
