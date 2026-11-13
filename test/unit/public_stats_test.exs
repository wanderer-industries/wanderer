defmodule WandererApp.PublicStatsTest do
  use ExUnit.Case, async: false

  alias WandererApp.Cache
  alias WandererApp.PublicStats

  test "counts online characters and distinct online users from the live character cache" do
    character_ids = [Ecto.UUID.generate(), Ecto.UUID.generate(), Ecto.UUID.generate()]
    {:ok, previous_tracked} = Cache.lookup("tracked_characters", [])

    on_exit(fn ->
      Cache.insert("tracked_characters", previous_tracked)
      Enum.each(character_ids, &Cachex.del(:character_cache, &1))
    end)

    Cache.insert("tracked_characters", character_ids)

    Cachex.put(:character_cache, Enum.at(character_ids, 0), %{
      online: true,
      user_id: "user-1",
      deleted: false
    })

    Cachex.put(:character_cache, Enum.at(character_ids, 1), %{
      online: true,
      user_id: "user-1",
      deleted: false
    })

    Cachex.put(:character_cache, Enum.at(character_ids, 2), %{
      online: false,
      user_id: "user-2",
      deleted: false
    })

    assert {:ok, %{online_users: 1, online_characters: 2}} =
             PublicStats.count_online_activity()
  end
end
