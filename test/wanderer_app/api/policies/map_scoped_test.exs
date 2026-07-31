defmodule WandererApp.Api.Policies.MapScopedTest do
  use WandererApp.DataCase, async: true
  alias WandererApp.Api.Policies.MapScoped
  alias WandererApp.Api.ActorWithMap

  describe "Trusted" do
    test "matches User" do
      assert MapScoped.Trusted.match?(%WandererApp.Api.User{id: Ecto.UUID.generate()}, %{}, [])
    end

    test "matches Character" do
      assert MapScoped.Trusted.match?(%WandererApp.Api.Character{id: Ecto.UUID.generate()}, %{}, [])
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
      assert {MapScoped.CreateParentInTokenMap, parent_resource: WandererApp.Api.MapSystem, fk: :system_id} =
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
end
