defmodule WandererApp.Api.Policies.MapScopedTest do
  use WandererApp.DataCase, async: true
  require Ash.Query
  alias WandererApp.Api.Policies.MapScoped
  alias WandererApp.Api.ActorWithMap

  describe "Trusted" do
    test "matches User" do
      assert MapScoped.Trusted.match?(%WandererApp.Api.User{id: Ecto.UUID.generate()}, %{}, [])
    end

    test "matches Character" do
      assert MapScoped.Trusted.match?(
               %WandererApp.Api.Character{id: Ecto.UUID.generate()},
               %{},
               []
             )
    end

    test "does NOT match session ActorWithMap{map: nil}" do
      refute MapScoped.Trusted.match?(ActorWithMap.new(%{id: "u"}, nil), %{}, [])
    end

    test "does NOT match token ActorWithMap{map: %{}}" do
      refute MapScoped.Trusted.match?(ActorWithMap.new(%{id: "u"}, %{id: "m"}), %{}, [])
    end

    test "does not match nil" do
      refute MapScoped.Trusted.match?(nil, %{}, [])
    end
  end

  describe "builders" do
    test "in_token_map/1" do
      assert {MapScoped.InTokenMap, path: [:map_id]} = MapScoped.in_token_map([:map_id])
    end

    test "create_parent_in_token_map/2" do
      assert {MapScoped.CreateParentInTokenMap,
              parent_resource: WandererApp.Api.MapSystem, fk: :system_id} =
               MapScoped.create_parent_in_token_map(WandererApp.Api.MapSystem, :system_id)
    end

    test "write_direct/1 default" do
      assert {MapScoped.WriteDirect, attr: :map_id} = MapScoped.write_direct()
    end

    test "write_direct/1 custom attr" do
      assert {MapScoped.WriteDirect, attr: :system_id} = MapScoped.write_direct(:system_id)
    end

    test "parent_in_token_map/1" do
      assert {MapScoped.ParentInTokenMap, path: [:system, :map_id]} =
               MapScoped.parent_in_token_map([:system, :map_id])
    end

    test "create_map_matches_token/0" do
      assert {MapScoped.CreateMapMatchesToken, []} = MapScoped.create_map_matches_token()
    end
  end

  describe "WriteDirect" do
    setup do
      map_id = Ecto.UUID.generate()
      actor = ActorWithMap.new(%{id: "u"}, %{id: map_id})
      %{map_id: map_id, actor: actor}
    end

    test "authorizes when changeset attribute matches token map", %{map_id: map_id, actor: actor} do
      cs =
        %WandererApp.Api.MapSystem{}
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:map_id, map_id)

      assert MapScoped.WriteDirect.match?(actor, %{changeset: cs}, attr: :map_id)
    end

    test "denies when changeset attribute is a foreign map", %{actor: actor} do
      cs =
        %WandererApp.Api.MapSystem{}
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:map_id, Ecto.UUID.generate())

      refute MapScoped.WriteDirect.match?(actor, %{changeset: cs}, attr: :map_id)
    end

    test "denies when actor has no token map", %{map_id: map_id} do
      no_map_actor = ActorWithMap.new(%{id: "u"}, nil)

      cs =
        %WandererApp.Api.MapSystem{}
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:map_id, map_id)

      refute MapScoped.WriteDirect.match?(no_map_actor, %{changeset: cs}, attr: :map_id)
    end
  end

  describe "CreateMapMatchesToken" do
    setup do
      map_id = Ecto.UUID.generate()
      actor = ActorWithMap.new(%{id: "u"}, %{id: map_id})
      %{map_id: map_id, actor: actor}
    end

    test "authorizes when map_id absent (will be injected)", %{actor: actor} do
      cs = Ash.Changeset.new(WandererApp.Api.MapSystem)
      assert MapScoped.CreateMapMatchesToken.match?(actor, %{changeset: cs}, [])
    end

    test "authorizes when supplied map_id equals token map", %{map_id: map_id, actor: actor} do
      cs = %{Ash.Changeset.new(WandererApp.Api.MapSystem) | params: %{"map_id" => map_id}}
      assert MapScoped.CreateMapMatchesToken.match?(actor, %{changeset: cs}, [])
    end

    test "forbids when supplied map_id is a foreign map", %{actor: actor} do
      cs = %{
        Ash.Changeset.new(WandererApp.Api.MapSystem)
        | params: %{"map_id" => Ecto.UUID.generate()}
      }

      refute MapScoped.CreateMapMatchesToken.match?(actor, %{changeset: cs}, [])
    end

    test "denies when actor has no token map" do
      no_map_actor = ActorWithMap.new(%{id: "u"}, nil)
      cs = Ash.Changeset.new(WandererApp.Api.MapSystem)
      refute MapScoped.CreateMapMatchesToken.match?(no_map_actor, %{changeset: cs}, [])
    end
  end

  describe "InTokenMap filter/3 (direct path, exercised against a real query)" do
    setup do
      map = insert(:map, %{})
      other_map = insert(:map, %{})
      system_in_map = insert(:map_system, %{map_id: map.id})
      system_in_other_map = insert(:map_system, %{map_id: other_map.id})
      actor = ActorWithMap.new(%{id: "u"}, %{id: map.id})

      %{
        map: map,
        actor: actor,
        system_in_map: system_in_map,
        system_in_other_map: system_in_other_map
      }
    end

    test "returned filter admits only rows in the token map", %{
      actor: actor,
      map: map,
      system_in_map: system_in_map,
      system_in_other_map: system_in_other_map
    } do
      filter = MapScoped.InTokenMap.filter(actor, %{}, path: [:map_id])

      # Assert directly on the raw filter value. MapSystem's primary :read
      # action has its own independent map-scoping preparation
      # (FilterSystemsByActorMap), which would make a query round-trip
      # pass even if this check's filter were stubbed to `expr(true)` — so
      # the round-trip below is a secondary sanity check, not proof this
      # check does the scoping.
      assert filter == [map_id: map.id]

      {:ok, results} =
        WandererApp.Api.MapSystem
        |> Ash.Query.filter(^filter)
        |> Ash.read(actor: actor, authorize?: false)

      ids = Enum.map(results, & &1.id)
      assert system_in_map.id in ids
      refute system_in_other_map.id in ids
    end

    test "returns expr(false) when actor has no token map" do
      no_map_actor = ActorWithMap.new(%{id: "u"}, nil)
      filter = MapScoped.InTokenMap.filter(no_map_actor, %{}, path: [:map_id])

      assert filter == false

      {:ok, results} =
        WandererApp.Api.MapSystem
        |> Ash.Query.filter(^filter)
        |> Ash.read(actor: no_map_actor, authorize?: false)

      assert results == []
    end
  end

  describe "ParentInTokenMap filter/3 (relationship path, exercised against a real query)" do
    setup do
      map = insert(:map, %{})
      other_map = insert(:map, %{})
      system_in_map = insert(:map_system, %{map_id: map.id})
      system_in_other_map = insert(:map_system, %{map_id: other_map.id})

      sig_in_map =
        insert(:map_system_signature, %{system_id: system_in_map.id})

      sig_in_other_map =
        insert(:map_system_signature, %{system_id: system_in_other_map.id})

      actor = ActorWithMap.new(%{id: "u"}, %{id: map.id})

      %{actor: actor, sig_in_map: sig_in_map, sig_in_other_map: sig_in_other_map}
    end

    test "returned filter admits only rows whose parent belongs to the token map", %{
      actor: actor,
      sig_in_map: sig_in_map,
      sig_in_other_map: sig_in_other_map
    } do
      filter = MapScoped.ParentInTokenMap.filter(actor, %{}, path: [:system, :map_id])

      {:ok, results} =
        WandererApp.Api.MapSystemSignature
        |> Ash.Query.filter(^filter)
        |> Ash.read(actor: actor, authorize?: false)

      ids = Enum.map(results, & &1.id)
      assert sig_in_map.id in ids
      refute sig_in_other_map.id in ids
    end

    test "returns expr(false) when actor has no token map" do
      no_map_actor = ActorWithMap.new(%{id: "u"}, nil)
      filter = MapScoped.ParentInTokenMap.filter(no_map_actor, %{}, path: [:system, :map_id])

      {:ok, results} =
        WandererApp.Api.MapSystemSignature
        |> Ash.Query.filter(^filter)
        |> Ash.read(actor: no_map_actor, authorize?: false)

      assert results == []
    end
  end

  describe "CreateParentInTokenMap" do
    setup do
      map = insert(:map, %{})
      other_map = insert(:map, %{})
      system_in_map = insert(:map_system, %{map_id: map.id})
      system_in_other_map = insert(:map_system, %{map_id: other_map.id})
      actor = ActorWithMap.new(%{id: "u"}, %{id: map.id})

      %{
        actor: actor,
        system_in_map: system_in_map,
        system_in_other_map: system_in_other_map
      }
    end

    test "authorizes when the parent (looked up by fk) belongs to the token map", %{
      actor: actor,
      system_in_map: system_in_map
    } do
      cs =
        WandererApp.Api.MapSystemSignature
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:system_id, system_in_map.id)

      assert MapScoped.CreateParentInTokenMap.match?(
               actor,
               %{changeset: cs},
               parent_resource: WandererApp.Api.MapSystem,
               fk: :system_id
             )
    end

    test "denies when the parent belongs to a foreign map", %{
      actor: actor,
      system_in_other_map: system_in_other_map
    } do
      cs =
        WandererApp.Api.MapSystemSignature
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:system_id, system_in_other_map.id)

      refute MapScoped.CreateParentInTokenMap.match?(
               actor,
               %{changeset: cs},
               parent_resource: WandererApp.Api.MapSystem,
               fk: :system_id
             )
    end
  end
end
