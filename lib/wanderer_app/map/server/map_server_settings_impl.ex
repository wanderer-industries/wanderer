defmodule WandererApp.Map.Server.SettingsImpl do
  @moduledoc false

  def handle_map_settings_updated(map_id, map_update) do
    WandererApp.Map.update_map(map_id, map_update)

    case WandererApp.Map.get_map_state(map_id, false) do
      {:ok, %{map: map}} when not is_nil(map) ->
        WandererApp.Map.update_map_state(map_id, %{map: Map.merge(map, map_update)})

      _ ->
        :ok
    end
  end
end
