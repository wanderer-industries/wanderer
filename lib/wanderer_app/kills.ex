defmodule WandererApp.Kills do
  @moduledoc """
  Main interface for the WandererKills integration subsystem.

  Provides high-level functions for monitoring and managing the kills
  data pipeline, including connection status, health metrics, and
  system subscriptions.
  """

  alias WandererApp.Kills.{Client, Storage}

  @doc """
  Gets comprehensive status of the kills subsystem.
  """
  @spec get_status() :: {:ok, map()} | {:error, term()}
  def get_status do
    with {:ok, client_status} <- Client.get_status() do
      {:ok,
       %{
         enabled: Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, false),
         client: client_status,
         websocket_url:
           Application.get_env(
             :wanderer_app,
             :wanderer_kills_base_url,
             "ws://wanderer-kills:4004"
           )
       }}
    end
  end

  @doc """
  Subscribes to killmail updates for specified systems.
  """
  @spec subscribe_systems([integer()]) :: :ok | {:error, term()}
  defdelegate subscribe_systems(system_ids), to: Client, as: :subscribe_to_systems

  @doc """
  Unsubscribes from killmail updates for specified systems.
  """
  @spec unsubscribe_systems([integer()]) :: :ok | {:error, term()}
  defdelegate unsubscribe_systems(system_ids), to: Client, as: :unsubscribe_from_systems

  @doc """
  Gets kill count for a specific system.
  """
  @spec get_system_kill_count(integer()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  defdelegate get_system_kill_count(system_id), to: Storage, as: :get_kill_count

  @doc """
  Gets recent kills for a specific system.
  """
  @spec get_system_kills(integer()) :: {:ok, list(map())} | {:error, :not_found}
  defdelegate get_system_kills(system_id), to: Storage

  @doc """
  Manually triggers a reconnection attempt.
  """
  @spec reconnect() :: :ok | {:error, term()}
  defdelegate reconnect(), to: Client
end
