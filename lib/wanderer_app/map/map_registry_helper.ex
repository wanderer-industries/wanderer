defmodule WandererApp.Map.RegistryHelper do
  @moduledoc false

  alias WandererApp.MapRegistry

  def list_all_maps(),
    do: Registry.select(MapRegistry, [{{:"$1", :"$2", :_}, [], [%{id: :"$1", pid: :"$2"}]}])

  def list_all_maps_by_map_id(map_id) do
    match_all = {:"$1", :"$2", :"$3"}
    guards = [{:==, :"$1", map_id}]
    map_result = [%{id: :"$1", pid: :"$2"}]
    Registry.select(MapRegistry, [{match_all, guards, map_result}])
  end
end
