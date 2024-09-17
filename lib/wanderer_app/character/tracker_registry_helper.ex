defmodule WandererApp.Character.TrackerRegistryHelper do
  @moduledoc false

  alias WandererApp.Character.TrackerRegistry

  def list_all_trackers(),
    do: Registry.select(TrackerRegistry, [{{:"$1", :"$2", :_}, [], [%{id: :"$1", pid: :"$2"}]}])

  def list_all_trackers_by_character_id(character_id) do
    match_all = {:"$1", :"$2", :"$3"}
    guards = [{:==, :"$1", character_id}]
    map_result = [%{id: :"$1", pid: :"$2"}]
    Registry.select(TrackerRegistry, [{match_all, guards, map_result}])
  end
end
