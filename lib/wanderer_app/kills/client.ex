defmodule WandererApp.Kills.Client do
  @moduledoc """
  WebSocket client for WandererKills service.

  Manages the complete WebSocket connection lifecycle, health monitoring,
  and system subscriptions for receiving killmail data.
  """

  use GenServer
  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  alias WandererApp.Kills.{Config, MessageHandler, RetryBehavior}
  alias WandererApp.Kills.Subscription.Manager, as: SubscriptionManager
  alias WandererApp.Kills.Subscription.MapIntegration
  alias Phoenix.Channels.GenSocketClient

  defstruct [
    :socket_pid,
    :server_url,
    :retry_timer_ref,
    connected: false,
    connecting: false,
    subscribed_systems: MapSet.new(),
    retry_state: %{retry_count: 0, cycle_count: 0}
  ]

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec subscribe_to_systems([integer()]) :: :ok
  def subscribe_to_systems(system_ids) do
    GenServer.cast(__MODULE__, {:subscribe_systems, system_ids})
  end

  @spec unsubscribe_from_systems([integer()]) :: :ok
  def unsubscribe_from_systems(system_ids) do
    GenServer.cast(__MODULE__, {:unsubscribe_systems, system_ids})
  end

  @spec get_status() :: {:ok, map()} | {:error, term()}
  def get_status do
    GenServer.call(__MODULE__, :get_status, Config.genserver_call_timeout())
  catch
    :exit, _ -> {:error, :not_running}
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    if Config.enabled?() do
      @logger.info("[KillsClient] Starting WandererKills WebSocket client")

      send(self(), :connect)
      schedule_health_check()
      schedule_cleanup()

      initial_state = %__MODULE__{
        server_url: Config.server_url(),
        retry_state: RetryBehavior.new_retry_state()
      }

      # Ensure all fields are present (for hot code reload compatibility)
      {:ok, Map.put_new(initial_state, :connecting, false)}
    else
      @logger.info("[KillsClient] WandererKills integration disabled")
      :ignore
    end
  end

  @impl true
  def handle_info(:connect, state) do
    new_state = attempt_connection(state)
    {:noreply, new_state}
  end

  def handle_info(:retry_connection, state) do
    # Clear the timer reference since it fired
    cleared_state = %{state | retry_timer_ref: nil}
    new_state = attempt_connection(cleared_state)
    {:noreply, new_state}
  end

  def handle_info({:connected, socket_pid}, state) do
    @logger.info("[KillsClient] WebSocket connected")

    # Cancel any pending retry timer
    RetryBehavior.cancel_retry_timer(state.retry_timer_ref)

    new_state = %{
      state
      | connected: true,
        connecting: false,
        socket_pid: socket_pid,
        retry_timer_ref: nil,
        retry_state: RetryBehavior.reset_retry_state(state.retry_state)
    }

    {:noreply, new_state}
  end

  def handle_info({:channel_joined, socket_pid}, state) do
    # Resubscribe to all systems now that we're in the channel
    if MapSet.size(state.subscribed_systems) > 0 do
      SubscriptionManager.resubscribe_all(socket_pid, state.subscribed_systems)
    end

    {:noreply, state}
  end

  def handle_info({:disconnected, reason}, state) do
    # Ensure connecting field exists (for backwards compatibility)
    state = Map.put_new(state, :connecting, false)

    cond do
      # Already disconnected and retry scheduled - ignore duplicate event
      not state.connected and state.retry_timer_ref != nil ->
        {:noreply, state}

      # Already disconnected but no retry scheduled (shouldn't happen)
      not state.connected ->
        @logger.warning(
          "[KillsClient] WebSocket already disconnected but no retry scheduled: #{inspect(reason)}"
        )

        new_retry_state = RetryBehavior.increment_retry(state.retry_state, get_retry_config())

        timer_ref =
          RetryBehavior.schedule_retry(new_retry_state, get_retry_config(), :retry_connection)

        new_state = %{state | retry_state: new_retry_state, retry_timer_ref: timer_ref}
        {:noreply, new_state}

      # First disconnect event
      true ->
        @logger.warning("[KillsClient] WebSocket disconnected: #{inspect(reason)}")
        new_retry_state = RetryBehavior.increment_retry(state.retry_state, get_retry_config())

        timer_ref =
          RetryBehavior.schedule_retry(new_retry_state, get_retry_config(), :retry_connection)

        new_state = %{
          state
          | connected: false,
            connecting: false,
            retry_state: new_retry_state,
            retry_timer_ref: timer_ref
        }

        {:noreply, new_state}
    end
  end

  def handle_info(:health_check, state) do
    new_state =
      case check_connection_health(state) do
        :ok ->
          @logger.debug("[KillsClient] Connection healthy")
          state

        {:reconnect, reason} ->
          case state.retry_timer_ref do
            nil ->
              # No retry currently scheduled, trigger reconnection
              @logger.warning(
                "[KillsClient] Connection unhealthy: #{reason}. Triggering reconnection."
              )

              new_retry_state =
                RetryBehavior.increment_retry(state.retry_state, get_retry_config())

              timer_ref =
                RetryBehavior.schedule_retry(
                  new_retry_state,
                  get_retry_config(),
                  :retry_connection
                )

              %{state | retry_state: new_retry_state, retry_timer_ref: timer_ref}

            _timer_ref ->
              # Retry already scheduled, don't interfere
              state
          end
      end

    schedule_health_check()
    {:noreply, new_state}
  end

  def handle_info(:cleanup_subscriptions, state) do
    {updated_systems, to_unsubscribe} =
      SubscriptionManager.cleanup_subscriptions(state.subscribed_systems)

    if length(to_unsubscribe) > 0 do
      SubscriptionManager.sync_with_server(state.socket_pid, [], to_unsubscribe)
    end

    schedule_cleanup()
    {:noreply, %{state | subscribed_systems: updated_systems}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe_systems, system_ids}, state) do
    {updated_systems, to_subscribe} =
      SubscriptionManager.subscribe_systems(state.subscribed_systems, system_ids)

    if length(to_subscribe) > 0 do
      SubscriptionManager.sync_with_server(state.socket_pid, to_subscribe, [])
    end

    {:noreply, %{state | subscribed_systems: updated_systems}}
  end

  def handle_cast({:unsubscribe_systems, system_ids}, state) do
    {updated_systems, to_unsubscribe} =
      SubscriptionManager.unsubscribe_systems(state.subscribed_systems, system_ids)

    if length(to_unsubscribe) > 0 do
      SubscriptionManager.sync_with_server(state.socket_pid, [], to_unsubscribe)
    end

    {:noreply, %{state | subscribed_systems: updated_systems}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      connection: get_connection_status(state),
      subscriptions: SubscriptionManager.get_stats(state.subscribed_systems),
      health: get_health_metrics(state),
      retry_state: state.retry_state
    }

    {:reply, {:ok, status}, state}
  end

  # Private functions - Connection Management

  defp attempt_connection(state) do
    # Ensure connecting field exists (for backwards compatibility)
    state = Map.put_new(state, :connecting, false)

    cond do
      # Already connecting - ignore this attempt
      state.connecting ->
        state

      # Not connecting - proceed with connection attempt
      true ->
        # Cancel any existing retry timer
        RetryBehavior.cancel_retry_timer(state.retry_timer_ref)
        disconnect(state.socket_pid)

        # Mark as disconnected and connecting
        connecting_state = %{
          state
          | connected: false,
            connecting: true,
            socket_pid: nil,
            retry_timer_ref: nil
        }

        case connect(connecting_state.server_url, connecting_state.subscribed_systems) do
          {:ok, socket_pid} ->
            %{connecting_state | socket_pid: socket_pid}

          {:error, _reason} ->
            @logger.error("[KillsClient] Connection failed")

            new_retry_state =
              RetryBehavior.increment_retry(connecting_state.retry_state, get_retry_config())

            timer_ref =
              RetryBehavior.schedule_retry(new_retry_state, get_retry_config(), :retry_connection)

            %{
              connecting_state
              | connecting: false,
                retry_state: new_retry_state,
                retry_timer_ref: timer_ref
            }
        end
    end
  end

  defp connect(server_url, subscribed_systems \\ MapSet.new()) do
    @logger.info("[KillsClient] Attempting to connect to: #{server_url}")

    handler_state = %{
      server_url: server_url,
      parent: self(),
      subscribed_systems: subscribed_systems
    }

    case GenSocketClient.start_link(
           __MODULE__.Handler,
           Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
           handler_state
         ) do
      {:ok, socket_pid} ->
        {:ok, socket_pid}

      {:error, reason} = error ->
        @logger.error("[KillsClient] Failed to start socket: #{inspect(reason)}")
        error
    end
  end

  defp disconnect(nil), do: :ok

  defp disconnect(socket_pid) when is_pid(socket_pid) do
    if Process.alive?(socket_pid) do
      GenServer.stop(socket_pid, :normal)
    end

    :ok
  end

  # Private functions - Health Monitoring

  defp schedule_health_check do
    interval = Config.health_check_interval()
    Process.send_after(self(), :health_check, interval)
  end

  defp schedule_cleanup do
    interval = Config.cleanup_interval()
    Process.send_after(self(), :cleanup_subscriptions, interval)
  end

  defp check_connection_health(%{connected: false}), do: {:reconnect, "Not connected"}
  defp check_connection_health(%{socket_pid: nil}), do: {:reconnect, "No socket PID"}

  defp check_connection_health(%{socket_pid: socket_pid, connected: true}) do
    if Process.alive?(socket_pid) do
      :ok
    else
      {:reconnect, "Socket process died"}
    end
  end

  defp get_health_metrics(state) do
    %{
      connected: state.connected,
      socket_alive:
        case state.socket_pid do
          nil -> false
          pid -> Process.alive?(pid)
        end,
      retry_count: state.retry_state.retry_count,
      subscribed_systems_count: MapSet.size(state.subscribed_systems)
    }
  end

  # Private functions - Retry Configuration

  defp get_retry_config do
    %{
      max_retries: Config.max_retries(),
      retry_delays: Config.retry_delays(),
      cycle_delay: Config.cycle_delay()
    }
  end

  # Private functions - Status

  defp get_connection_status(state) do
    %{
      connected: state.connected,
      socket_alive:
        case state.socket_pid do
          nil -> false
          pid -> Process.alive?(pid)
        end,
      server_url: state.server_url,
      socket_pid: inspect(state.socket_pid)
    }
  end

  defmodule Handler do
    @moduledoc false
    @behaviour Phoenix.Channels.GenSocketClient
    require Logger

    @logger Application.compile_env(:wanderer_app, :logger)

    alias WandererApp.Kills.{Config, MessageHandler}
    alias WandererApp.Kills.Subscription.MapIntegration

    @impl true
    def init(state) do
      ws_url = "#{state.server_url}/socket/websocket"
      {:connect, ws_url, [vsn: Config.websocket_version()], state}
    end

    @impl true
    def handle_connected(transport, state) do
      # First check if we have subscribed systems from reconnection
      systems =
        if Map.has_key?(state, :subscribed_systems) and MapSet.size(state.subscribed_systems) > 0 do
          MapSet.to_list(state.subscribed_systems)
        else
          # Fall back to getting systems from MapIntegration for initial connection
          case MapIntegration.get_tracked_system_ids() do
            {:ok, system_list} ->
              system_list

            {:error, reason} ->
              @logger.error("[KillsClient] Failed to get tracked systems: #{inspect(reason)}")
              []
          end
        end

      case Phoenix.Channels.GenSocketClient.join(transport, "killmails:lobby", %{
             systems: systems,
             client_identifier: Config.client_identifier()
           }) do
        {:ok, _response} ->
          send(state.parent, {:connected, self()})
          {:ok, state}

        {:error, reason} ->
          @logger.error("[KillsClient] Failed to join channel: #{inspect(reason)}")
          send(state.parent, {:disconnected, {:join_error, reason}})
          {:ok, state}
      end
    end

    @impl true
    def handle_disconnected(reason, state) do
      @logger.warning("[KillsClient] WebSocket disconnected: #{inspect(reason)}")
      send(state.parent, {:disconnected, reason})
      {:ok, state}
    end

    @impl true
    def handle_channel_closed(topic, _payload, _transport, state) do
      @logger.warning("[KillsClient] Channel #{topic} closed")
      send(state.parent, {:disconnected, {:channel_closed, topic}})
      {:ok, state}
    end

    @impl true
    def handle_message(topic, event, payload, _transport, state) do
      case {topic, event} do
        {"killmails:lobby", "killmail_update"} ->
          Task.start(fn -> MessageHandler.process_killmail_update(payload) end)
          {:ok, state}

        {"killmails:lobby", "kill_count_update"} ->
          Task.start(fn -> MessageHandler.process_kill_count_update(payload) end)
          {:ok, state}

        _ ->
          {:ok, state}
      end
    end

    @impl true
    def handle_reply(_topic, _ref, _payload, _transport, state) do
      {:ok, state}
    end

    @impl true
    def handle_info({:subscribe_systems, system_ids}, transport, state) do
      case Phoenix.Channels.GenSocketClient.push(
             transport,
             "killmails:lobby",
             "subscribe_systems",
             %{systems: system_ids}
           ) do
        {:ok, _ref} ->
          {:ok, state}

        {:error, reason} ->
          @logger.error("[KillsClient] Failed to subscribe: #{inspect(reason)}")
          {:ok, state}
      end
    end

    def handle_info({:unsubscribe_systems, system_ids}, transport, state) do
      case Phoenix.Channels.GenSocketClient.push(
             transport,
             "killmails:lobby",
             "unsubscribe_systems",
             %{systems: system_ids}
           ) do
        {:ok, _ref} ->
          {:ok, state}

        {:error, reason} ->
          @logger.error("[KillsClient] Failed to unsubscribe: #{inspect(reason)}")
          {:ok, state}
      end
    end

    def handle_info(_msg, _transport, state) do
      {:ok, state}
    end

    @impl true
    def handle_call(_msg, _from, _transport, state) do
      {:reply, {:error, :not_implemented}, state}
    end

    @impl true
    def handle_joined(_topic, _payload, _transport, state) do
      send(state.parent, {:channel_joined, self()})
      {:ok, state}
    end

    @impl true
    def handle_join_error(topic, payload, _transport, state) do
      send(state.parent, {:disconnected, {:join_error, {topic, payload}}})
      {:ok, state}
    end
  end
end
