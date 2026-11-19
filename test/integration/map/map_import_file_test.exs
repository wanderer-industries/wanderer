defmodule WandererApp.Map.MapImportFileTest do
  @moduledoc """
  Importing a document that carries system status and notes.

  This is the shape people actually hand to an import: systems with a status colour and a note
  written on them, which is what has to come out the other side.
  """

  use WandererApp.DataCase

  import WandererApp.MapTestHelpers

  alias WandererApp.Map.Operations.Transfer
  alias WandererApp.Map.Server

  @friendly 31_001_825
  @warning 31_001_589
  @plain 31_001_745

  @document %{
    "version" => 1,
    "map" => %{"name" => "mendy", "slug" => "mendy", "description" => nil},
    "systems" => [
      %{
        "solar_system_id" => @friendly,
        "position" => %{"x" => 120, "y" => 240},
        "name" => "J165636",
        "custom_name" => "Szpital Psychiatryczny",
        "description" => "mili goscie od Estiego",
        "labels" => nil,
        "status" => 1,
        "tag" => nil,
        "temporary_name" => nil,
        "locked" => false
      },
      %{
        "solar_system_id" => @warning,
        "position" => %{"x" => 300, "y" => 240},
        "name" => "J110145",
        "custom_name" => "The Pond",
        "description" => nil,
        "labels" => nil,
        "status" => 2,
        "tag" => nil,
        "temporary_name" => nil,
        "locked" => false
      },
      %{
        "solar_system_id" => @plain,
        "position" => %{"x" => 480, "y" => 240},
        "name" => "J121030",
        "custom_name" => nil,
        "description" => "farmery c5 marudery",
        "labels" => nil,
        "status" => 4,
        "tag" => nil,
        "temporary_name" => nil,
        "locked" => false
      }
    ],
    "connections" => [
      %{
        "source" => @friendly,
        "target" => @warning,
        "type" => 0,
        "mass_status" => 0,
        "time_status" => 0,
        "ship_size_type" => 2,
        "wormhole_type" => nil,
        "locked" => false
      }
    ],
    "signatures" => []
  }

  setup do
    setup_import_test_systems()
    :ok
  end

  test "a system keeps the status and the note the document carries for it" do
    target = start_test_map()

    {:ok, stats} =
      Transfer.import(target.map_id, @document, target.user_id, target.character_id)

    assert stats.systems == 3

    assert %{status: 1, description: "mili goscie od Estiego"} =
             imported(target.map_id, @friendly)

    assert %{status: 2} = imported(target.map_id, @warning)
    assert %{status: 4, description: "farmery c5 marudery"} = imported(target.map_id, @plain)
  end

  test "a system already on the target map takes the status and the note it is missing" do
    target = start_test_map()

    # the chain is already there, as it is when somebody imports onto a live map
    :ok =
      Server.add_system(
        target.map_id,
        %{solar_system_id: @friendly, coordinates: %{"x" => 0, "y" => 0}},
        target.user_id,
        target.character_id
      )

    assert wait_for_system_on_map(target.map_id, @friendly)

    {:ok, _stats} =
      Transfer.import(target.map_id, @document, target.user_id, target.character_id)

    assert %{status: status, description: description} = imported(target.map_id, @friendly)

    assert status == 1
    assert description == "mili goscie od Estiego"
  end

  test "a note somebody wrote on the target map is not overwritten by the document" do
    target = start_test_map()

    :ok =
      Server.add_system(
        target.map_id,
        %{solar_system_id: @friendly, coordinates: %{"x" => 0, "y" => 0}},
        target.user_id,
        target.character_id
      )

    assert wait_for_system_on_map(target.map_id, @friendly)

    Server.update_system_description(target.map_id, %{
      solar_system_id: @friendly,
      description: "ours"
    })

    Server.update_system_status(target.map_id, %{solar_system_id: @friendly, status: 3})

    {:ok, _stats} =
      Transfer.import(target.map_id, @document, target.user_id, target.character_id)

    assert %{status: 3, description: "ours"} = imported(target.map_id, @friendly)
  end

  defp imported(map_id, solar_system_id) do
    {:ok, system} =
      WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id)

    %{status: system.status, description: system.description}
  end

  defp start_test_map do
    setup_ddrt_mocks()

    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    map = insert(:map, %{owner_id: character.id})

    :ok = ensure_map_started(map.id)

    %{map_id: map.id, user_id: user.id, character_id: character.id}
  end

  defp setup_import_test_systems do
    [@friendly, @warning, @plain]
    |> Enum.with_index()
    |> Map.new(fn {solar_system_id, index} ->
      {solar_system_id,
       %{
         solar_system_id: solar_system_id,
         solar_system_name: "J10110#{index}",
         solar_system_name_lc: "j10110#{index}",
         region_id: 11_000_001,
         constellation_id: 21_000_001,
         region_name: "A-R00001",
         constellation_name: "A-C00001",
         system_class: 5,
         security: "-1.0",
         type_description: "Class 5",
         class_title: "C5",
         is_shattered: false,
         effect_name: nil,
         effect_power: nil,
         statics: [],
         wandering: [],
         triglavian_invasion_status: nil,
         sun_type_id: 45041
       }}
    end)
    |> setup_system_static_info_cache()
  end
end
