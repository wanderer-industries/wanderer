defmodule WandererApp.Map.MapConnectionFlagsTest do
  @moduledoc """
  Connections carry their own dangerous and bubbled flags, set from the context menu rather than
  derived from the systems they link.
  """

  use WandererApp.DataCase

  import WandererApp.MapTestHelpers

  alias WandererApp.Map.Server

  @system_a 31_000_001
  @system_b 31_000_002

  setup do
    setup_connection_test_systems()
    :ok
  end

  describe "connection flags" do
    test "dangerous is stored and kept in map state" do
      %{map_id: map_id} = start_map_with_connection()

      :ok =
        Server.update_connection_dangerous(map_id, %{
          solar_system_source_id: @system_a,
          solar_system_target_id: @system_b,
          dangerous: true
        })

      assert {:ok, connection} = find_connection(map_id)
      assert connection.dangerous

      assert {:ok, cached} = WandererApp.Map.find_connection(map_id, @system_a, @system_b)
      assert cached.dangerous

      cleanup_test_data(map_id)
    end

    test "bubbled records which ends are covered" do
      %{map_id: map_id} = start_map_with_connection()

      :ok =
        Server.update_connection_bubbled(map_id, %{
          solar_system_source_id: @system_a,
          solar_system_target_id: @system_b,
          bubbled: 2
        })

      assert {:ok, connection} = find_connection(map_id)
      assert connection.bubbled == 2

      :ok =
        Server.update_connection_bubbled(map_id, %{
          solar_system_source_id: @system_a,
          solar_system_target_id: @system_b,
          bubbled: 0
        })

      assert {:ok, connection} = find_connection(map_id)
      assert connection.bubbled == 0

      cleanup_test_data(map_id)
    end

    test "a new connection starts with neither flag set" do
      %{map_id: map_id} = start_map_with_connection()

      assert {:ok, connection} = find_connection(map_id)
      refute connection.dangerous
      assert connection.bubbled == 0

      cleanup_test_data(map_id)
    end
  end

  defp find_connection(map_id) do
    WandererApp.MapConnectionRepo.get_by_map(map_id)
    |> case do
      {:ok, connections} ->
        connections
        |> Enum.find(&(&1.solar_system_source == @system_a and &1.solar_system_target == @system_b))
        |> case do
          nil -> {:error, :not_found}
          connection -> {:ok, connection}
        end

      error ->
        error
    end
  end

  defp start_map_with_connection do
    setup_ddrt_mocks()

    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    map = insert(:map, %{owner_id: character.id})

    :ok = ensure_map_started(map.id)

    Enum.each([@system_a, @system_b], fn solar_system_id ->
      :ok =
        Server.add_system(
          map.id,
          %{solar_system_id: solar_system_id, coordinates: %{"x" => 0, "y" => 0}},
          user.id,
          character.id
        )

      assert wait_for_system_on_map(map.id, solar_system_id)
    end)

    Server.add_connection(map.id, %{
      solar_system_source_id: @system_a,
      solar_system_target_id: @system_b,
      character_id: character.id
    })

    %{map_id: map.id, user_id: user.id, character_id: character.id}
  end

  defp setup_connection_test_systems do
    setup_system_static_info_cache(%{
      @system_a => %{
        solar_system_id: @system_a,
        solar_system_name: "J100001",
        solar_system_name_lc: "j100001",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: 1,
        security: "-1.0"
      },
      @system_b => %{
        solar_system_id: @system_b,
        solar_system_name: "J100002",
        solar_system_name_lc: "j100002",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: 2,
        security: "-1.0"
      }
    })
  end
end
