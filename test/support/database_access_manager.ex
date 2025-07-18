defmodule WandererApp.Test.DatabaseAccessManager do
  @moduledoc """
  Comprehensive database access management for integration tests.

  This module provides utilities to ensure that all processes spawned during
  integration tests have proper database sandbox access.
  """

  @doc """
  Grants database access to a process and monitors for child processes.

  This function not only grants access to the given process but also
  monitors it for child processes and grants access to them as well.
  """
  def grant_database_access(pid, owner_pid \\ self()) do
    # Grant access to the primary process (basic sandbox access)
    try do
      Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, owner_pid, pid)
    rescue
      # Ignore errors if already allowed
      _ -> :ok
    end

    # Set up lightweight monitoring for child processes
    setup_lightweight_monitoring(pid, owner_pid)

    :ok
  end

  @doc """
  Grants database access to a GenServer and all its potential child processes.

  This includes monitoring for Task.async processes, linked processes,
  and any other processes that might be spawned by the GenServer.
  """
  def grant_genserver_database_access(genserver_pid, owner_pid \\ self()) do
    # Grant access to the GenServer itself
    grant_database_access(genserver_pid, owner_pid)

    # Get all current linked processes and grant them access (once)
    grant_access_to_linked_processes(genserver_pid, owner_pid)

    :ok
  end

  @doc """
  Grants database access to all processes in a supervision tree.

  This recursively grants access to all processes under a supervisor.
  """
  def grant_supervision_tree_access(supervisor_pid, owner_pid \\ self()) do
    # Grant access to the supervisor
    grant_database_access(supervisor_pid, owner_pid)

    # Get all children and grant them access
    children = get_supervisor_children(supervisor_pid)

    Enum.each(children, fn child_pid ->
      grant_database_access(child_pid, owner_pid)

      # If the child is also a supervisor, recurse
      if is_supervisor?(child_pid) do
        grant_supervision_tree_access(child_pid, owner_pid)
      end
    end)

    :ok
  end

  @doc """
  Monitors a process for database access issues and automatically grants access.

  This sets up a monitoring process that watches for database access errors
  and automatically grants access to processes that need it.
  """
  def setup_automatic_access_granting(monitored_pid, owner_pid \\ self()) do
    spawn_link(fn ->
      Process.monitor(monitored_pid)
      monitor_for_database_access_errors(monitored_pid, owner_pid)
    end)
  end

  # Private helper functions

  defp setup_lightweight_monitoring(parent_pid, owner_pid) do
    # Simple one-time check for immediate child processes
    spawn(fn ->
      # Give process time to spawn children
      :timer.sleep(100)
      grant_access_to_linked_processes(parent_pid, owner_pid)
    end)
  end

  defp setup_child_process_monitoring(parent_pid, owner_pid) do
    spawn_link(fn ->
      Process.monitor(parent_pid)
      monitor_for_new_processes(parent_pid, owner_pid, get_process_children(parent_pid))
    end)
  end

  defp grant_access_to_linked_processes(pid, owner_pid) do
    case Process.info(pid, :links) do
      {:links, links} ->
        links
        |> Enum.filter(&is_pid/1)
        |> Enum.filter(&Process.alive?/1)
        |> Enum.each(fn linked_pid ->
          try do
            Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, owner_pid, linked_pid)
          rescue
            # Ignore errors if already allowed
            _ -> :ok
          end
        end)

      nil ->
        :ok
    end
  end

  defp setup_continuous_monitoring(genserver_pid, owner_pid) do
    spawn_link(fn ->
      Process.monitor(genserver_pid)
      continuously_monitor_genserver(genserver_pid, owner_pid)
    end)
  end

  defp continuously_monitor_genserver(genserver_pid, owner_pid) do
    if Process.alive?(genserver_pid) do
      # Check for new linked processes
      grant_access_to_linked_processes(genserver_pid, owner_pid)

      # Check for new child processes
      current_children = get_process_children(genserver_pid)

      Enum.each(current_children, fn child_pid ->
        grant_database_access(child_pid, owner_pid)
      end)

      # Continue monitoring
      :timer.sleep(100)
      continuously_monitor_genserver(genserver_pid, owner_pid)
    end
  end

  defp monitor_for_new_processes(parent_pid, owner_pid, previous_children) do
    if Process.alive?(parent_pid) do
      current_children = get_process_children(parent_pid)
      new_children = current_children -- previous_children

      # Grant access to new child processes
      Enum.each(new_children, fn child_pid ->
        grant_database_access(child_pid, owner_pid)
      end)

      # Continue monitoring
      :timer.sleep(50)
      monitor_for_new_processes(parent_pid, owner_pid, current_children)
    end
  end

  defp monitor_for_database_access_errors(monitored_pid, owner_pid) do
    if Process.alive?(monitored_pid) do
      # Monitor for error messages that indicate database access issues
      receive do
        {:DOWN, _ref, :process, ^monitored_pid, _reason} ->
          :ok
      after
        100 ->
          # Check for any processes that might need database access
          check_and_grant_access_to_related_processes(monitored_pid, owner_pid)
          monitor_for_database_access_errors(monitored_pid, owner_pid)
      end
    end
  end

  defp check_and_grant_access_to_related_processes(monitored_pid, owner_pid) do
    # Get all processes related to the monitored process
    related_processes = get_related_processes(monitored_pid)

    Enum.each(related_processes, fn pid ->
      grant_database_access(pid, owner_pid)
    end)
  end

  defp get_related_processes(pid) do
    # Get linked processes
    linked =
      case Process.info(pid, :links) do
        {:links, links} -> Enum.filter(links, &is_pid/1)
        nil -> []
      end

    # Get child processes
    children = get_process_children(pid)

    # Combine and filter for alive processes
    (linked ++ children)
    |> Enum.uniq()
    |> Enum.filter(&Process.alive?/1)
  end

  defp get_process_children(pid) do
    case Process.info(pid, :links) do
      {:links, links} ->
        links
        |> Enum.filter(&is_pid/1)
        |> Enum.filter(&Process.alive?/1)
        |> Enum.filter(fn linked_pid ->
          # Check if this is a child process (not just a linked process)
          case Process.info(linked_pid, :parent) do
            {:parent, ^pid} -> true
            _ -> false
          end
        end)

      nil ->
        []
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
    end
  end
end
