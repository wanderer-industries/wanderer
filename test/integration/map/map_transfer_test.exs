defmodule WandererApp.Map.MapTransferTest do
  @moduledoc """
  The export/import round trip.

  Covers the three things the shape of this feature rests on: what comes out of a map goes back
  into an empty one, running the same document twice adds nothing the second time, and a system
  deleted from the target comes back with the attributes the document carries for it.
  """

  use WandererApp.DataCase

  import WandererApp.MapTestHelpers

  alias WandererApp.Api.MapSystemSignature
  alias WandererApp.Map.Operations.Transfer
  alias WandererApp.Map.Server

  @system_a 31_000_101
  @system_b 31_000_102

  setup do
    setup_transfer_test_systems()
    :ok
  end

  describe "export/2 then import/5" do
    test "carries systems, their attributes, connections and signatures into an empty map" do
      source = start_test_map()
      target = start_test_map()

      seed_source_map(source)

      {:ok, document} = Transfer.export(source.map_id)

      assert document["version"] == 1
      assert length(document["systems"]) == 2
      assert length(document["connections"]) == 1
      assert length(document["signatures"]) == 1

      {:ok, stats} =
        Transfer.import(target.map_id, document, target.user_id, target.character_id)

      assert stats == %{systems: 2, connections: 1, signatures: 1}

      assert wait_for_system_on_map(target.map_id, @system_a)
      assert wait_for_system_on_map(target.map_id, @system_b)

      {:ok, system} =
        WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(target.map_id, @system_a)

      assert system.custom_name == "Home"
      assert system.description == "staging"
      assert system.tag == "A"
      assert system.status == 1
      assert system.temporary_name == "HS-1"
      assert system.position_x == 120
      assert system.position_y == 240

      {:ok, connections} = WandererApp.MapConnectionRepo.get_by_map(target.map_id)
      assert length(connections) == 1

      {:ok, signatures} = MapSystemSignature.by_system_id(system.id)
      assert [%{eve_id: "ABC-123", name: "Wormhole"}] = signatures

      cleanup_test_data(source.map_id)
      cleanup_test_data(target.map_id)
    end

    test "a second import of the same document adds nothing and says so" do
      source = start_test_map()
      target = start_test_map()

      seed_source_map(source)

      {:ok, document} = Transfer.export(source.map_id)

      {:ok, _first} =
        Transfer.import(target.map_id, document, target.user_id, target.character_id)

      assert wait_for_system_on_map(target.map_id, @system_a)

      {:ok, second} =
        Transfer.import(target.map_id, document, target.user_id, target.character_id)

      # the counts are the only feedback anyone gets about an import being safe to re-run, so a
      # no-op has to report zeroes rather than the size of the document
      assert second == %{systems: 0, connections: 0, signatures: 0}

      cleanup_test_data(source.map_id)
      cleanup_test_data(target.map_id)
    end

    test "a system deleted from the target comes back with its attributes" do
      source = start_test_map()
      target = start_test_map()

      seed_source_map(source)

      {:ok, document} = Transfer.export(source.map_id)
      {:ok, _} = Transfer.import(target.map_id, document, target.user_id, target.character_id)

      assert wait_for_system_on_map(target.map_id, @system_a)

      :ok = Server.delete_systems(target.map_id, [@system_a], target.user_id, target.character_id)

      refute system_visible?(target.map_id, @system_a)

      {:ok, stats} =
        Transfer.import(target.map_id, document, target.user_id, target.character_id)

      # deletion leaves the row behind with visible: false, so counting rows rather than systems
      # on the map used to treat this one as already present - it came back stripped
      assert stats.systems == 1

      assert wait_for_system_on_map(target.map_id, @system_a)

      {:ok, system} =
        WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(target.map_id, @system_a)

      assert system.custom_name == "Home"
      assert system.tag == "A"
      assert system.status == 1
      assert system.temporary_name == "HS-1"

      cleanup_test_data(source.map_id)
      cleanup_test_data(target.map_id)
    end
  end

  describe "import/5 with a document it cannot read" do
    test "refuses another version and anything that is not a document" do
      %{map_id: map_id, user_id: user_id, character_id: character_id} = start_test_map()

      assert {:error, {:unsupported_version, 99}} =
               Transfer.import(map_id, %{"version" => 99}, user_id, character_id)

      assert {:error, :invalid_document} = Transfer.import(map_id, %{}, user_id, character_id)

      cleanup_test_data(map_id)
    end
  end

  defp seed_source_map(%{map_id: map_id, user_id: user_id, character_id: character_id}) do
    :ok =
      Server.add_system(
        map_id,
        %{solar_system_id: @system_a, coordinates: %{"x" => 120, "y" => 240}},
        user_id,
        character_id
      )

    :ok =
      Server.add_system(
        map_id,
        %{solar_system_id: @system_b, coordinates: %{"x" => 300, "y" => 240}},
        user_id,
        character_id
      )

    assert wait_for_system_on_map(map_id, @system_a)
    assert wait_for_system_on_map(map_id, @system_b)

    Server.update_system_custom_name(map_id, %{solar_system_id: @system_a, custom_name: "Home"})

    Server.update_system_description(map_id, %{solar_system_id: @system_a, description: "staging"})

    Server.update_system_tag(map_id, %{solar_system_id: @system_a, tag: "A"})
    Server.update_system_status(map_id, %{solar_system_id: @system_a, status: 1})

    Server.update_system_temporary_name(map_id, %{
      solar_system_id: @system_a,
      temporary_name: "HS-1"
    })

    :ok =
      Server.add_connection(
        map_id,
        %{
          solar_system_source_id: @system_a,
          solar_system_target_id: @system_b,
          character_id: character_id
        }
      )

    {:ok, system} = WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, @system_a)

    {:ok, _} =
      MapSystemSignature.create(%{
        system_id: system.id,
        eve_id: "ABC-123",
        character_eve_id: "90000001",
        name: "Wormhole",
        kind: "cosmic_signature",
        group: "Wormhole"
      })

    :ok
  end

  defp system_visible?(map_id, solar_system_id) do
    case WandererApp.MapSystemRepo.get_visible_by_map(map_id) do
      {:ok, systems} -> Enum.any?(systems, &(&1.solar_system_id == solar_system_id))
      _ -> false
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

  defp setup_transfer_test_systems do
    setup_system_static_info_cache(%{
      @system_a => %{
        solar_system_id: @system_a,
        solar_system_name: "J101101",
        solar_system_name_lc: "j101101",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: 1,
        security: "-1.0"
      },
      @system_b => %{
        solar_system_id: @system_b,
        solar_system_name: "J101102",
        solar_system_name_lc: "j101102",
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
