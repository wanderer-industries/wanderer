defmodule WandererApp.Api.ActorWithMapTest do
  use ExUnit.Case, async: true

  alias WandererApp.Api.ActorWithMap

  describe "new/2" do
    test "creates ActorWithMap struct with user and map" do
      user = %{id: "user-123", name: "Test User"}
      map = %{id: "map-456", name: "Test Map"}

      actor = ActorWithMap.new(user, map)

      assert %ActorWithMap{user: ^user, map: ^map} = actor
    end
  end

  describe "user/1" do
    test "returns the user from ActorWithMap" do
      user = %{id: "user-123", name: "Test User"}
      map = %{id: "map-456"}
      actor = ActorWithMap.new(user, map)

      assert ActorWithMap.user(actor) == user
    end
  end

  describe "map/1" do
    test "returns the map from ActorWithMap" do
      user = %{id: "user-123"}
      map = %{id: "map-456", name: "Test Map"}
      actor = ActorWithMap.new(user, map)

      assert ActorWithMap.map(actor) == map
    end
  end

  describe "Access protocol implementation" do
    setup do
      user = %{
        id: "user-123",
        name: "Test User",
        email: "test@example.com",
        hash: "user-hash-123"
      }

      map = %{id: "map-456", name: "Test Map"}
      actor = ActorWithMap.new(user, map)

      {:ok, actor: actor, user: user, map: map}
    end

    test "fetches user fields via bracket syntax", %{actor: actor} do
      assert actor[:id] == "user-123"
      assert actor[:name] == "Test User"
      assert actor[:email] == "test@example.com"
      assert actor[:hash] == "user-hash-123"
    end

    test "returns nil for nonexistent fields", %{actor: actor} do
      assert actor[:nonexistent] == nil
    end

    test "works with Access.get/3 with default values", %{actor: actor} do
      assert Access.get(actor, :id, "default") == "user-123"
      assert Access.get(actor, :nonexistent, "default") == "default"
    end

    test "fetch/2 returns {:ok, value} for existing fields", %{actor: actor} do
      assert Access.fetch(actor, :id) == {:ok, "user-123"}
      assert Access.fetch(actor, :name) == {:ok, "Test User"}
    end

    test "fetch/2 returns :error for nonexistent fields", %{actor: actor} do
      assert Access.fetch(actor, :nonexistent) == :error
    end

    test "get_and_update/3 updates user field and returns new actor", %{actor: actor} do
      {old_name, updated_actor} =
        Access.get_and_update(actor, :name, fn current ->
          {current, "Updated Name"}
        end)

      assert old_name == "Test User"
      assert updated_actor[:name] == "Updated Name"
      assert updated_actor.map == actor.map
      # Original actor is unchanged
      assert actor[:name] == "Test User"
    end

    test "get_and_update/3 can add new fields", %{actor: actor} do
      {old_value, updated_actor} =
        Access.get_and_update(actor, :new_field, fn current ->
          {current, "new_value"}
        end)

      assert old_value == nil
      assert updated_actor[:new_field] == "new_value"
    end

    test "get_and_update/3 can remove fields by returning :pop", %{actor: actor} do
      {old_name, updated_actor} =
        Access.get_and_update(actor, :name, fn _current ->
          :pop
        end)

      assert old_name == "Test User"
      assert updated_actor[:name] == nil
      refute Map.has_key?(updated_actor.user, :name)
    end

    test "pop/2 removes field and returns value", %{actor: actor} do
      {value, updated_actor} = Access.pop(actor, :name)

      assert value == "Test User"
      assert updated_actor[:name] == nil
      refute Map.has_key?(updated_actor.user, :name)
      # Map is preserved
      assert updated_actor.map == actor.map
    end

    test "pop/2 returns nil for nonexistent field", %{actor: actor} do
      {value, updated_actor} = Access.pop(actor, :nonexistent)

      assert value == nil
      assert updated_actor == actor
    end

    test "works with Kernel.get_in/2", %{actor: actor} do
      assert get_in(actor, [:id]) == "user-123"
      assert get_in(actor, [:name]) == "Test User"
    end

    test "works with Kernel.put_in/3", %{actor: actor} do
      updated_actor = put_in(actor[:name], "New Name")

      assert updated_actor[:name] == "New Name"
      assert actor[:name] == "Test User"
    end

    test "works with Kernel.update_in/3", %{actor: actor} do
      updated_actor = update_in(actor[:name], &String.upcase/1)

      assert updated_actor[:name] == "TEST USER"
      assert actor[:name] == "Test User"
    end

    test "supports string keys", %{actor: actor} do
      user = %{"id" => "user-456", "name" => "String Keys"}
      map = %{"id" => "map-789"}
      string_actor = ActorWithMap.new(user, map)

      assert string_actor["id"] == "user-456"
      assert string_actor["name"] == "String Keys"
    end

    test "maintains struct type after updates", %{actor: actor} do
      updated_actor = put_in(actor[:name], "New Name")

      assert %ActorWithMap{} = updated_actor
    end

    test "does not allow direct access to nested actor fields" do
      user = %{id: "user-123", profile: %{age: 30}}
      map = %{id: "map-456"}
      actor = ActorWithMap.new(user, map)

      # Direct nested access via Access protocol doesn't work (this is expected)
      # You need to access in two steps
      assert actor[:profile] == %{age: 30}
      assert get_in(actor, [:profile, :age]) == 30
    end
  end
end
