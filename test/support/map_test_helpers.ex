defmodule WandererApp.MapTestHelpers do
  @moduledoc """
  Shared helper functions for map-related integration tests.

  This module provides common functionality for testing map servers,
  character location tracking, and system management.
  """

  import Mox

  @doc """
  Helper function to expect a map server error response.
  This function is used across multiple test files to handle
  map server errors consistently in unit test environments.
  """
  def expect_map_server_error(test_fun) do
    try do
      test_fun.()
    rescue
      MatchError ->
        # Expected when map or character doesn't exist in unit tests
        :ok
    catch
      "Map server not started" ->
        # Expected in unit test environment - map servers aren't started
        :ok
    end
  end

  @doc """
  Ensures the map is started for the given map ID.
  Uses async Map.Manager.start_map and waits for completion.

  IMPORTANT: This also grants database access to any dynamically spawned
  MapPool processes, which is required for async tests.

  ## Parameters
  - map_id: The ID of the map to start

  ## Examples
      iex> ensure_map_started(map.id)
      :ok
  """
  def ensure_map_started(map_id) do
    # Queue the map for starting (async)
    :ok = WandererApp.Map.Manager.start_map(map_id)

    # Continuously grant database access to any newly spawned processes
    # This ensures MapPool processes that spawn during initialization get access
    grant_database_access_continuously()

    # Wait for the map to actually start
    wait_for_map_started(map_id)
  end

  @doc """
  Ensures the map is stopped for the given map ID.
  """
  def ensure_map_stopped(map_id) do
    case WandererApp.Map.Manager.stop_map(map_id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      false -> :ok
    end

    # Wait for it to disappear from registry
    wait_for_map_stopped(map_id)
  end

  def wait_for_map_stopped(map_id, timeout \\ 5000) do
    start_time = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn ->
      {:ok, started_maps} = WandererApp.Cache.lookup("started_maps", [])

      if map_id not in started_maps do
        :ok
      else
        if System.monotonic_time(:millisecond) - start_time > timeout do
          raise "Map #{map_id} failed to stop within #{timeout}ms"
        end

        Process.sleep(10)
        :continue
      end
    end)
    |> Enum.find(&(&1 == :ok))
  end

  # Continuously grants database access to all MapPool processes and their children.
  # This is necessary when maps are started dynamically during tests.
  # Uses efficient polling with minimal delays.
  defp grant_database_access_continuously do
    owner_pid = Process.get(:sandbox_owner_pid) || self()

    # Grant access with minimal delays - 5 quick passes to catch spawned processes
    # Total time: ~25ms instead of 170ms
    Enum.each(1..5, fn _ ->
      grant_database_access_to_map_pools(owner_pid)
      Process.sleep(5)
    end)
  end

  defp grant_database_access_to_map_pools(owner_pid) do
    # Grant access to the MapPool supervisor and all its children
    case Process.whereis(WandererApp.Map.MapPoolSupervisor) do
      pid when is_pid(pid) ->
        WandererApp.Test.DatabaseAccessManager.grant_supervision_tree_access(pid, owner_pid)
        WandererApp.Test.MockOwnership.allow_supervision_tree(pid, owner_pid)

      _ ->
        :ok
    end

    # Also grant access to the MapPoolDynamicSupervisor and its children
    case Process.whereis(WandererApp.Map.MapPoolDynamicSupervisor) do
      pid when is_pid(pid) ->
        WandererApp.Test.DatabaseAccessManager.grant_supervision_tree_access(pid, owner_pid)
        WandererApp.Test.MockOwnership.allow_supervision_tree(pid, owner_pid)

      _ ->
        :ok
    end
  end

  @doc """
  Waits for a map to finish starting by polling the cache.

  ## Parameters
  - map_id: The ID of the map to wait for
  - timeout: Maximum time to wait in milliseconds (default: 10000)

  ## Examples
      iex> wait_for_map_started(map.id, 5000)
      :ok
  """
  def wait_for_map_started(map_id, timeout \\ 10_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      # Check both the map_started flag and the started_maps list
      map_started_flag =
        case WandererApp.Cache.lookup("map_#{map_id}:started") do
          {:ok, true} -> true
          _ -> false
        end

      in_started_maps_list =
        case WandererApp.Cache.lookup("started_maps", []) do
          {:ok, started_maps} when is_list(started_maps) ->
            Enum.member?(started_maps, map_id)

          _ ->
            false
        end

      cond do
        # Map is fully started
        map_started_flag and in_started_maps_list ->
          {:ok, :started}

        # Map is partially started or not started yet - keep waiting
        true ->
          if System.monotonic_time(:millisecond) < deadline do
            Process.sleep(20)
            :continue
          else
            {:error, :timeout}
          end
      end
    end)
    |> Enum.find(fn result -> result != :continue end)
    |> case do
      {:ok, :started} ->
        # Brief pause for subsystem initialization (reduced from 200ms)
        Process.sleep(50)
        :ok

      {:error, :timeout} ->
        raise "Timeout waiting for map #{map_id} to start. Check Map.Manager is running."
    end
  end

  @doc """
  Sets up DDRT (R-tree spatial index) mock stubs.
  This is required for system positioning on the map.
  We stub all R-tree operations to allow systems to be placed anywhere.

  IMPORTANT: This sets the mock to :global mode so it works with GenServers
  started in separate processes (like MapPool).

  ## Examples
      iex> setup_ddrt_mocks()
      :ok
  """
  def setup_ddrt_mocks do
    # Set mock to global mode so it works in child processes (MapPool, etc.)
    Mox.set_mox_global()

    Test.DDRTMock
    |> stub(:init_tree, fn _name, _opts -> :ok end)
    |> stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> stub(:delete, fn _ids, _tree_name -> {:ok, %{}} end)
    # query returns empty list to indicate no spatial conflicts (position is available)
    |> stub(:query, fn _bbox, _tree_name -> {:ok, []} end)

    :ok
  end

  @doc """
  Populates the system static info cache with data for common test systems.
  This is required for SystemsImpl.maybe_add_system to work properly,
  as it needs to fetch system names and other metadata.

  ## Parameters
  - systems: Map of solar_system_id => system_info (optional, uses defaults if not provided)

  ## Examples
      iex> setup_system_static_info_cache()
      :ok
  """
  def setup_system_static_info_cache(systems \\ nil) do
    test_systems = systems || default_test_systems()

    Enum.each(test_systems, fn {solar_system_id, system_info} ->
      Cachex.put(:system_static_info_cache, solar_system_id, system_info)
    end)

    :ok
  end

  @doc """
  Returns default test system configurations for common EVE systems.

  ## Examples
      iex> default_test_systems()
      %{30_000_142 => %{...}}
  """
  def default_test_systems do
    %{
      # Jita
      30_000_142 => %{
        solar_system_id: 30_000_142,
        region_id: 10_000_002,
        constellation_id: 20_000_020,
        solar_system_name: "Jita",
        solar_system_name_lc: "jita",
        constellation_name: "Kimotoro",
        region_name: "The Forge",
        system_class: 0,
        security: "0.9",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # Amarr
      30_002_187 => %{
        solar_system_id: 30_002_187,
        region_id: 10_000_043,
        constellation_id: 20_000_304,
        solar_system_name: "Amarr",
        solar_system_name_lc: "amarr",
        constellation_name: "Throne Worlds",
        region_name: "Domain",
        system_class: 0,
        security: "1.0",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # Dodixie
      30_002_659 => %{
        solar_system_id: 30_002_659,
        region_id: 10_000_032,
        constellation_id: 20_000_413,
        solar_system_name: "Dodixie",
        solar_system_name_lc: "dodixie",
        constellation_name: "Sinq Laison",
        region_name: "Sinq Laison",
        system_class: 0,
        security: "0.9",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # Rens
      30_002_510 => %{
        solar_system_id: 30_002_510,
        region_id: 10_000_030,
        constellation_id: 20_000_387,
        solar_system_name: "Rens",
        solar_system_name_lc: "rens",
        constellation_name: "Frarn",
        region_name: "Heimatar",
        system_class: 0,
        security: "0.9",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      }
    }
  end

  @doc """
  Helper to simulate character location update in cache.
  This mimics what the Character.Tracker does when it polls ESI.

  ## Parameters
  - character_id: The character ID to update
  - solar_system_id: The solar system ID where the character is located
  - opts: Optional parameters (structure_id, station_id, ship)

  ## Examples
      iex> set_character_location(character.id, 30_000_142, ship: 670)
      :ok
  """
  def set_character_location(character_id, solar_system_id, opts \\ []) do
    structure_id = opts[:structure_id]
    station_id = opts[:station_id]
    # Capsule
    ship = opts[:ship] || 670

    # First get the existing character from cache or database to maintain all fields
    {:ok, existing_character} = WandererApp.Character.get_character(character_id)

    # Update character cache (mimics Character.update_character/2)
    character_data =
      Map.merge(existing_character, %{
        solar_system_id: solar_system_id,
        structure_id: structure_id,
        station_id: station_id,
        ship: ship,
        updated_at: DateTime.utc_now()
      })

    Cachex.put(:character_cache, character_id, character_data)
  end

  @doc """
  Helper to add character to map's presence list.
  This mimics what PresenceGracePeriodManager does.

  ## Parameters
  - map_id: The map ID
  - character_id: The character ID to add

  ## Examples
      iex> add_character_to_map_presence(map.id, character.id)
      :ok
  """
  def add_character_to_map_presence(map_id, character_id) do
    {:ok, current_chars} = WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])
    updated_chars = Enum.uniq([character_id | current_chars])
    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", updated_chars)
  end

  @doc """
  Helper to get all systems currently on the map.
  Uses :map_cache instead of :map_state_cache because add_system/2 updates :map_cache.

  ## Parameters
  - map_id: The map ID

  ## Returns
  - List of systems on the map

  ## Examples
      iex> get_map_systems(map.id)
      [%{solar_system_id: 30_000_142, ...}, ...]
  """
  def get_map_systems(map_id) do
    case WandererApp.Map.get_map(map_id) do
      {:ok, %{systems: systems}} when is_map(systems) ->
        Map.values(systems)

      {:ok, _} ->
        []

      {:error, _} ->
        []
    end
  end

  @doc """
  Checks if a specific system is on the map.

  ## Parameters
  - map_id: The map ID
  - solar_system_id: The solar system ID to check

  ## Returns
  - true if the system is on the map, false otherwise

  ## Examples
      iex> system_on_map?(map.id, 30_000_142)
      true
  """
  def system_on_map?(map_id, solar_system_id) do
    systems = get_map_systems(map_id)
    Enum.any?(systems, fn sys -> sys.solar_system_id == solar_system_id end)
  end

  @doc """
  Waits for a system to appear on the map (for async operations).

  ## Parameters
  - map_id: The map ID
  - solar_system_id: The solar system ID to wait for
  - timeout: Maximum time to wait in milliseconds (default: 2000)

  ## Returns
  - true if the system appears on the map, false if timeout

  ## Examples
      iex> wait_for_system_on_map(map.id, 30_000_142, 5000)
      true
  """
  def wait_for_system_on_map(map_id, solar_system_id, timeout \\ 2000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      if system_on_map?(map_id, solar_system_id) do
        {:ok, true}
      else
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(10)
          :continue
        else
          {:error, :timeout}
        end
      end
    end)
    |> Enum.find(fn result -> result != :continue end)
    |> case do
      {:ok, true} -> true
      {:error, :timeout} -> false
    end
  end

  @doc """
  Cleans up character location caches for a specific character and map.

  ## Parameters
  - map_id: The map ID
  - character_id: The character ID

  ## Examples
      iex> cleanup_character_caches(map.id, character.id)
      :ok
  """
  def cleanup_character_caches(map_id, character_id) do
    # Clean up character location caches
    WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
    WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:start_solar_system_id")
    WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:station_id")
    WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:structure_id")

    # Clean up character cache
    if Cachex.exists?(:character_cache, character_id) do
      Cachex.del(:character_cache, character_id)
    end

    # Clean up character state cache
    if Cachex.exists?(:character_state_cache, character_id) do
      Cachex.del(:character_state_cache, character_id)
    end

    :ok
  end

  @doc """
  Cleans up test data for a map.

  ## Parameters
  - map_id: The map ID

  ## Examples
      iex> cleanup_test_data(map.id)
      :ok
  """
  def cleanup_test_data(map_id) do
    # Clean up map-level presence tracking
    WandererApp.Cache.delete("map_#{map_id}:presence_character_ids")
    :ok
  end
end
