defmodule WandererApp.Test.MockOwnership do
  @moduledoc """
  Manages Mox ownership for dynamically spawned processes.

  This module provides utilities to grant mock access to processes
  spawned during tests while using Mox in private mode.
  """

  @doc """
  Allows all configured mocks for a given process.
  Call this for every process that needs to use mocks.
  """
  def allow_mocks_for_process(pid, owner_pid \\ self()) do
    if Code.ensure_loaded?(Mox) do
      mocks = [
        Test.DDRTMock,
        Test.LoggerMock,
        Test.PubSubMock,
        WandererApp.CachedInfo.Mock,
        Test.CacheMock,
        Test.MapRepoMock,
        Test.MapConnectionRepoMock,
        Test.MapMock,
        Test.MapCharacterSettingsRepoMock,
        Test.CharacterMock,
        Test.MapUserSettingsRepoMock,
        Test.TrackingUtilsMock,
        Test.MapSystemRepoMock,
        Test.MapServerMock,
        Test.OperationsMock,
        Test.MapSystemSignatureMock,
        Test.MapSystemMock,
        Test.ConnectionsMock,
        Test.TrackingConfigUtilsMock,
        Test.CharacterApiMock,
        Test.UserApiMock,
        Test.TelemetryMock,
        Test.AshMock,
        WandererApp.Esi.Mock
      ]

      Enum.each(mocks, fn mock ->
        try do
          Mox.allow(mock, owner_pid, pid)
        rescue
          # Mock might not be defined or already allowed
          _ -> :ok
        end
      end)
    end

    :ok
  end

  @doc """
  Sets up mock ownership for a GenServer and monitors for child processes.
  """
  def setup_genserver_mocks(genserver_pid, owner_pid \\ self()) do
    allow_mocks_for_process(genserver_pid, owner_pid)

    # Monitor for child processes and grant them access
    if Process.alive?(genserver_pid) do
      spawn_link(fn ->
        Process.monitor(genserver_pid)
        monitor_for_children(genserver_pid, owner_pid)
      end)
    end

    :ok
  end

  @doc """
  Grants mock access to an entire supervision tree.
  """
  def allow_supervision_tree(supervisor_pid, owner_pid \\ self()) do
    allow_mocks_for_process(supervisor_pid, owner_pid)

    children = get_supervisor_children(supervisor_pid)

    Enum.each(children, fn child_pid ->
      allow_mocks_for_process(child_pid, owner_pid)

      if is_supervisor?(child_pid) do
        allow_supervision_tree(child_pid, owner_pid)
      end
    end)

    :ok
  end

  # Private helpers

  defp monitor_for_children(parent_pid, owner_pid, interval \\ 100) do
    if Process.alive?(parent_pid) do
      :timer.sleep(interval)

      # Get new child processes and grant access
      case Process.info(parent_pid, :links) do
        {:links, links} ->
          links
          |> Enum.filter(&is_pid/1)
          |> Enum.filter(&Process.alive?/1)
          |> Enum.each(&allow_mocks_for_process(&1, owner_pid))

        nil ->
          :ok
      end

      monitor_for_children(parent_pid, owner_pid, interval)
    end
  end

  defp get_supervisor_children(supervisor_pid) do
    try do
      case Supervisor.which_children(supervisor_pid) do
        children when is_list(children) ->
          children
          |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
          |> Enum.filter(&is_pid/1)
          |> Enum.filter(&Process.alive?/1)

        _ ->
          []
      end
    rescue
      _ -> []
    catch
      :exit, _ -> []
    end
  end

  defp is_supervisor?(pid) do
    try do
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Keyword.get(dict, :"$initial_call") == {:supervisor, :init, 1}

        _ ->
          false
      end
    rescue
      _ -> false
    catch
      :exit, _ -> false
    end
  end
end
