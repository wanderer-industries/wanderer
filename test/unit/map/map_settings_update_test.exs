defmodule WandererApp.Map.Server.MapSettingsUpdateTest do
  use ExUnit.Case, async: false

  alias WandererApp.Map.Server.SettingsImpl

  test "updates the running map cache and state" do
    map_id = Ecto.UUID.generate()

    on_exit(fn ->
      WandererApp.Map.delete_map(map_id)
      WandererApp.Map.delete_map_state(map_id)
    end)

    WandererApp.Map.update_map(map_id, %{name: "Old name", scopes: [:wormholes]})

    Cachex.put(:map_state_cache, map_id, %{
      map: %{name: "Old name", scopes: [:wormholes]},
      map_id: map_id
    })

    SettingsImpl.handle_map_settings_updated(map_id, %{
      name: "New name",
      scopes: [:wormholes, :null]
    })

    assert {:ok, %{name: "New name", scopes: [:wormholes, :null]}} =
             WandererApp.Map.get_map(map_id)

    assert {:ok, %{map: %{name: "New name", scopes: [:wormholes, :null]}}} =
             WandererApp.Map.get_map_state(map_id, false)
  end
end
