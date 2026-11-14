defmodule WandererApp.Map.IntelSyncTest do
  use WandererApp.DataCase, async: false

  import Mox
  import WandererApp.MapTestHelpers

  alias WandererApp.Map.IntelSync

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()
    setup_ddrt_mocks()
    setup_system_static_info_cache()

    previous_intel_sharing =
      Application.get_env(:wanderer_app, :intel_sharing_enabled)

    on_exit(fn ->
      Application.put_env(:wanderer_app, :intel_sharing_enabled, previous_intel_sharing)
    end)

    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    source_map = insert(:map, %{owner_id: character.id})
    subscriber_map = insert(:map, %{owner_id: character.id})

    # Set subscriber's intel source
    {:ok, _} = WandererApp.MapRepo.set_intel_source_map(subscriber_map, source_map.id)

    # Create a system on the source map with intel fields populated
    source_system =
      insert(:map_system, %{
        map_id: source_map.id,
        solar_system_id: 30_000_142,
        visible: true
      })

    # Update source system with intel data
    {:ok, source_system} =
      WandererApp.Api.MapSystem.update_intel(source_system, %{
        custom_name: "Source Custom Name",
        description: "Source description",
        tag: "T1",
        temporary_name: "TmpName",
        labels: Jason.encode!(["la"]),
        status: 1
      })

    # Create matching system on subscriber map with empty intel
    subscriber_system =
      insert(:map_system, %{
        map_id: subscriber_map.id,
        solar_system_id: 30_000_142,
        visible: true
      })

    %{
      source_map: source_map,
      subscriber_map: subscriber_map,
      source_system: source_system,
      subscriber_system: subscriber_system,
      character: character,
      user: user
    }
  end

  defp enable_intel_sharing do
    Application.put_env(:wanderer_app, :intel_sharing_enabled, true)
  end

  defp disable_intel_sharing do
    Application.put_env(:wanderer_app, :intel_sharing_enabled, false)
  end

  describe "sync_system/3" do
    test "copies intel fields from source to subscriber", ctx do
      enable_intel_sharing()

      assert {:ok, updated_system} =
               IntelSync.sync_system(
                 ctx.subscriber_map.id,
                 ctx.source_map.id,
                 30_000_142
               )

      assert updated_system.custom_name == "Source Custom Name"
      assert updated_system.description == "Source description"
      assert updated_system.tag == "T1"
      assert updated_system.temporary_name == "TmpName"
      assert updated_system.labels == Jason.encode!(["la"])
      assert updated_system.status == 1
    end

    test "returns {:ok, :no_source_data} when source has no system", ctx do
      enable_intel_sharing()

      assert {:ok, :no_source_data} =
               IntelSync.sync_system(
                 ctx.subscriber_map.id,
                 ctx.source_map.id,
                 99_999_999
               )
    end

    test "returns {:ok, :disabled} when feature flag is off", ctx do
      disable_intel_sharing()

      assert {:ok, :disabled} =
               IntelSync.sync_system(
                 ctx.subscriber_map.id,
                 ctx.source_map.id,
                 30_000_142
               )
    end

    test "copies comments and marks them inherited", ctx do
      enable_intel_sharing()

      # Create a comment on the source system
      {:ok, _comment} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.source_system.id,
          character_id: ctx.character.id,
          text: "Intel comment from source"
        })

      # Sync
      {:ok, _updated} =
        IntelSync.sync_system(
          ctx.subscriber_map.id,
          ctx.source_map.id,
          30_000_142
        )

      # Fetch comments for subscriber system
      {:ok, comments} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      inherited =
        Enum.filter(comments, fn c ->
          c.inherited_from_map_id == ctx.source_map.id
        end)

      assert length(inherited) == 1
      assert Enum.any?(inherited, fn c -> c.text == "Intel comment from source" end)
    end

    test "copies structures and marks them inherited", ctx do
      enable_intel_sharing()

      # Create a structure on the source system
      {:ok, _structure} =
        WandererApp.Api.MapSystemStructure.create(%{
          system_id: ctx.source_system.id,
          structure_type_id: "35825",
          structure_type: "Astrahus",
          character_eve_id: "2000000001",
          solar_system_name: "Jita",
          solar_system_id: 30_000_142,
          name: "Test Structure From Source",
          status: "anchored"
        })

      # Sync
      {:ok, _updated} =
        IntelSync.sync_system(
          ctx.subscriber_map.id,
          ctx.source_map.id,
          30_000_142
        )

      # Fetch structures for subscriber system
      {:ok, structures} =
        WandererApp.Api.MapSystemStructure.by_system_id(ctx.subscriber_system.id)

      inherited =
        Enum.filter(structures, fn s ->
          s.inherited_from_map_id == ctx.source_map.id
        end)

      assert length(inherited) == 1
      assert Enum.any?(inherited, fn s -> s.name == "Test Structure From Source" end)
    end

    test "replaces inherited comments on re-sync (does not duplicate)", ctx do
      enable_intel_sharing()

      # Create a comment on the source system
      {:ok, _comment} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.source_system.id,
          character_id: ctx.character.id,
          text: "Re-sync comment"
        })

      # Sync once
      {:ok, _} =
        IntelSync.sync_system(
          ctx.subscriber_map.id,
          ctx.source_map.id,
          30_000_142
        )

      {:ok, comments_after_first} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      inherited_count_first =
        comments_after_first
        |> Enum.count(fn c -> c.inherited_from_map_id == ctx.source_map.id end)

      # Sync again
      {:ok, _} =
        IntelSync.sync_system(
          ctx.subscriber_map.id,
          ctx.source_map.id,
          30_000_142
        )

      {:ok, comments_after_second} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      inherited_count_second =
        comments_after_second
        |> Enum.count(fn c -> c.inherited_from_map_id == ctx.source_map.id end)

      assert inherited_count_first == inherited_count_second
    end

    test "does NOT copy already-inherited comments from source", ctx do
      enable_intel_sharing()

      # Use the subscriber_map.id as the "other" map so the FK constraint is satisfied
      # (inherited_from_map_id must reference a real map)
      other_map_id = ctx.subscriber_map.id

      {:ok, _inherited_comment} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.source_system.id,
          character_id: ctx.character.id,
          text: "Already inherited comment",
          inherited_from_map_id: other_map_id
        })

      # Sync
      {:ok, _} =
        IntelSync.sync_system(
          ctx.subscriber_map.id,
          ctx.source_map.id,
          30_000_142
        )

      # Fetch comments for subscriber system
      {:ok, comments} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      # The already-inherited comment should NOT be copied
      already_inherited =
        Enum.filter(comments, fn c ->
          c.text == "Already inherited comment"
        end)

      assert length(already_inherited) == 0
    end
  end

  describe "inherited_solar_system_ids/2" do
    test "returns only the systems the source map also has", ctx do
      enable_intel_sharing()

      # Present on the subscriber but not on the source: stays editable.
      insert(:map_system, %{
        map_id: ctx.subscriber_map.id,
        solar_system_id: 30_002_659,
        visible: true
      })

      assert [30_000_142] ==
               IntelSync.inherited_solar_system_ids(ctx.subscriber_map.id, ctx.source_map.id)
    end

    test "returns [] when the map has no source", ctx do
      enable_intel_sharing()

      assert [] == IntelSync.inherited_solar_system_ids(ctx.subscriber_map.id, nil)
    end

    test "returns [] when the feature flag is off", ctx do
      disable_intel_sharing()

      assert [] ==
               IntelSync.inherited_solar_system_ids(ctx.subscriber_map.id, ctx.source_map.id)
    end
  end

  describe "inherited_system?/2" do
    setup ctx do
      Cachex.put(:map_state_cache, ctx.subscriber_map.id, %{
        map: %WandererApp.Map{
          map_id: ctx.subscriber_map.id,
          intel_source_map_id: ctx.source_map.id
        }
      })

      on_exit(fn -> Cachex.del(:map_state_cache, ctx.subscriber_map.id) end)

      :ok
    end

    test "true when the source map has the system", ctx do
      enable_intel_sharing()

      assert IntelSync.inherited_system?(ctx.subscriber_map.id, 30_000_142)
    end

    test "false when the source map does not have the system", ctx do
      enable_intel_sharing()

      refute IntelSync.inherited_system?(ctx.subscriber_map.id, 99_999_999)
    end

    test "false when the feature flag is off", ctx do
      disable_intel_sharing()

      refute IntelSync.inherited_system?(ctx.subscriber_map.id, 30_000_142)
    end

    test "false when the map has no cached state", ctx do
      enable_intel_sharing()

      refute IntelSync.inherited_system?(ctx.source_map.id, 30_000_142)
    end
  end

  describe "clear_inherited_from/2" do
    test "removes inherited records but leaves the map's own", ctx do
      enable_intel_sharing()

      {:ok, _} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.source_system.id,
          character_id: ctx.character.id,
          text: "From source"
        })

      {:ok, _} =
        WandererApp.Api.MapSystemStructure.create(%{
          system_id: ctx.source_system.id,
          structure_type_id: "35825",
          structure_type: "Astrahus",
          character_eve_id: "2000000001",
          solar_system_name: "Jita",
          solar_system_id: 30_000_142,
          name: "From source",
          status: "anchored"
        })

      {:ok, _} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.subscriber_system.id,
          character_id: ctx.character.id,
          text: "Locally written"
        })

      {:ok, _} = IntelSync.sync_system(ctx.subscriber_map.id, ctx.source_map.id, 30_000_142)

      assert {:ok, _cleared} =
               IntelSync.clear_inherited_from(ctx.subscriber_map.id, ctx.source_map.id)

      {:ok, comments} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      {:ok, structures} =
        WandererApp.Api.MapSystemStructure.by_system_id(ctx.subscriber_system.id)

      assert Enum.all?(comments, &is_nil(&1.inherited_from_map_id))
      assert Enum.map(comments, & &1.text) == ["Locally written"]
      assert structures == []
    end

    test "is a no-op when there is no previous source", ctx do
      enable_intel_sharing()

      assert {:ok, 0} == IntelSync.clear_inherited_from(ctx.subscriber_map.id, nil)
    end
  end

  describe "SystemsImpl.remove_system_comment/4" do
    test "refuses to delete an inherited comment", ctx do
      enable_intel_sharing()

      {:ok, _} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.source_system.id,
          character_id: ctx.character.id,
          text: "From source"
        })

      {:ok, _} = IntelSync.sync_system(ctx.subscriber_map.id, ctx.source_map.id, 30_000_142)

      {:ok, [inherited]} =
        WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      assert :ok ==
               WandererApp.Map.Server.SystemsImpl.remove_system_comment(
                 ctx.subscriber_map.id,
                 inherited.id,
                 ctx.user.id,
                 ctx.character.id
               )

      assert {:ok, [still_there]} =
               WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)

      assert still_there.id == inherited.id
    end

    test "still deletes a comment the map owns", ctx do
      {:ok, own} =
        WandererApp.Api.MapSystemComment.create(%{
          system_id: ctx.subscriber_system.id,
          character_id: ctx.character.id,
          text: "Locally written"
        })

      assert :ok ==
               WandererApp.Map.Server.SystemsImpl.remove_system_comment(
                 ctx.subscriber_map.id,
                 own.id,
                 ctx.user.id,
                 ctx.character.id
               )

      assert {:ok, []} =
               WandererApp.Api.MapSystemComment.by_system_id(ctx.subscriber_system.id)
    end
  end

  describe "sync_all_visible_systems/2" do
    test "syncs all visible systems", ctx do
      enable_intel_sharing()

      # Create a second system on both maps (first one is already set up in setup)
      source_system_2 =
        insert(:map_system, %{
          map_id: ctx.source_map.id,
          solar_system_id: 30_002_659,
          visible: true
        })

      {:ok, _source_system_2} =
        WandererApp.Api.MapSystem.update_intel(source_system_2, %{
          custom_name: "Source System 2",
          description: "Description 2"
        })

      _subscriber_system_2 =
        insert(:map_system, %{
          map_id: ctx.subscriber_map.id,
          solar_system_id: 30_002_659,
          visible: true
        })

      assert {:ok, count} =
               IntelSync.sync_all_visible_systems(
                 ctx.subscriber_map.id,
                 ctx.source_map.id
               )

      assert count == 2
    end

    test "returns {:ok, :disabled} when feature off", ctx do
      disable_intel_sharing()

      assert {:ok, :disabled} =
               IntelSync.sync_all_visible_systems(
                 ctx.subscriber_map.id,
                 ctx.source_map.id
               )
    end
  end
end
