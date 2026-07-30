defmodule WandererApp.Map.MapPasteSystemsTest do
  @moduledoc """
  Copy/paste carries system attributes between maps.

  Pasting a selection into a map where those systems do not exist yet used to create them from
  static info alone, so status, tag, labels, description and temporary name were dropped - the
  copy only looked right when pasted back onto a map that already had the systems.
  """

  use WandererApp.DataCase

  import WandererApp.MapTestHelpers

  alias WandererApp.Map.Server

  @wh_system_j100001 31_000_001
  @wh_system_j100002 31_000_002

  setup do
    setup_paste_test_systems()
    :ok
  end

  describe "paste_systems/5 into a map without those systems" do
    test "keeps status, tag, labels, description and temporary name" do
      %{map_id: map_id, user_id: user_id, character_id: character_id} = start_test_map()

      Server.paste_systems(
        map_id,
        [
          %{
            "id" => "#{@wh_system_j100001}",
            "position" => %{"x" => 120, "y" => 240},
            "name" => "J100001",
            "description" => "staging",
            "labels" => ~s({"customLabel":"WH-1","labels":["a"]}),
            "status" => 1,
            "tag" => "A",
            "temporary_name" => "Home"
          }
        ],
        user_id,
        character_id
      )

      assert wait_for_system_on_map(map_id, @wh_system_j100001)

      {:ok, system} =
        WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, @wh_system_j100001)

      assert system.position_x == 120
      assert system.position_y == 240
      assert system.status == 1
      assert system.tag == "A"
      assert system.temporary_name == "Home"
      assert system.description == "staging"
      assert system.labels == ~s({"customLabel":"WH-1","labels":["a"]})

      cleanup_test_data(map_id)
    end

    test "a paste without attributes still creates the system" do
      %{map_id: map_id, user_id: user_id, character_id: character_id} = start_test_map()

      Server.paste_systems(
        map_id,
        [%{"id" => "#{@wh_system_j100002}", "position" => %{"x" => 10, "y" => 20}}],
        user_id,
        character_id
      )

      assert wait_for_system_on_map(map_id, @wh_system_j100002)

      {:ok, system} =
        WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, @wh_system_j100002)

      assert system.name == "J100002"
      assert system.status == 0

      cleanup_test_data(map_id)
    end
  end

  defp start_test_map do
    setup_ddrt_mocks()

    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    map = insert(:map, %{owner_id: character.id})

    :ok = ensure_map_started(map.id)

    %{map_id: map.id, user_id: user.id, character_id: character.id}
  end

  defp setup_paste_test_systems do
    setup_system_static_info_cache(%{
      @wh_system_j100001 => %{
        solar_system_id: @wh_system_j100001,
        solar_system_name: "J100001",
        solar_system_name_lc: "j100001",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: 1,
        security: "-1.0"
      },
      @wh_system_j100002 => %{
        solar_system_id: @wh_system_j100002,
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
