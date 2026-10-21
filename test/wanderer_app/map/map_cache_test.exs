defmodule WandererApp.MapCacheTest do
  use ExUnit.Case, async: false

  alias WandererApp.Map, as: MapCache

  test "parallel system position updates do not overwrite each other" do
    map_id = Ecto.UUID.generate()

    systems =
      Map.new(1..50, fn id ->
        {id, %{solar_system_id: id, position_x: 0, position_y: 0}}
      end)

    {:ok, true} = Cachex.put(:map_cache, map_id, %{systems: systems})
    on_exit(fn -> Cachex.del(:map_cache, map_id) end)

    results =
      1..50
      |> Task.async_stream(
        fn id ->
          MapCache.update_system_by_solar_system_id(map_id, %{
            solar_system_id: id,
            position_x: id * 10,
            position_y: id * 20
          })
        end,
        max_concurrency: 16,
        ordered: false
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, :ok}, &1))
    cached_systems = MapCache.get_map!(map_id).systems

    assert Enum.all?(1..50, fn id ->
             cached_systems[id].position_x == id * 10 and
               cached_systems[id].position_y == id * 20
           end)
  end
end
