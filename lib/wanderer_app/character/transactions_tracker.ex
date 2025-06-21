defmodule WandererApp.Character.TransactionsTracker do
  @moduledoc false
  use GenServer, restart: :transient

  require Logger

  alias WandererApp.GenImpl
  alias WandererApp.Character.TransactionsTracker.Impl

  def start_link(args),
    do: GenServer.start_link(__MODULE__, args, name: via(args[:character_id]))

  def update(character_id),
    do: GenServer.cast(via(character_id), {&Impl.update/1, []})

  def get_total_balance(character_id),
    do: GenServer.call(via(character_id), {&Impl.get_total_balance/1, []})

  def get_transactions(character_id),
    do: GenServer.call(via(character_id), {&Impl.get_transactions/1, []})

  def pid(character_id),
    do:
      character_id
      |> via()
      |> GenServer.whereis()

  @impl true
  def init(args) do
    Logger.info("#{__MODULE__} started for #{args[:character_id]}")

    {:ok, Impl.init(args), {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    {:noreply, state |> Impl.start()}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

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
  def handle_info(:shutdown, %Impl{} = state) do
    Logger.debug(fn ->
      "Shutting down character transaction tracker: #{inspect(state.character_id)}"
    end)

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(event, state), do: {:noreply, Impl.handle_event(event, state)}

  defp via(character_id) do
    {:via, Registry, {WandererApp.Character.TrackerRegistry, "transactions:#{character_id}"}}
  end
end
