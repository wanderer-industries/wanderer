defmodule WandererAppWeb.FactoryTest do
  use WandererApp.DataCase, async: true

  describe "Factory data creation" do
    test "creates valid user" do
      user = insert(:user)

      assert user.id
      assert user.hash
      assert is_binary(user.hash)
      assert user.name
      assert is_binary(user.name)
    end

    test "creates valid character" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      assert character.id
      assert character.eve_id
      assert character.name
      assert character.user_id == user.id
      assert is_binary(character.eve_id)
      assert is_binary(character.name)
    end

    test "creates valid map" do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      assert map.id
      assert map.name
      assert map.slug
      assert map.owner_id == character.id
      assert is_binary(map.name)
      assert is_binary(map.slug)
    end

    test "creates valid map system" do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})
      system = insert(:map_system, %{map_id: map.id})

      assert system.id
      assert system.map_id == map.id
      assert system.solar_system_id
      assert is_integer(system.solar_system_id)
    end

    test "creates valid map connection" do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      connection =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: 30_000_142,
          solar_system_target: 30_000_144
        })

      assert connection.id
      assert connection.map_id == map.id
      assert connection.solar_system_source == 30_000_142
      assert connection.solar_system_target == 30_000_144
    end

    test "creates valid map character settings" do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      settings =
        insert(:map_character_settings, %{
          map_id: map.id,
          character_id: character.id,
          tracked: true
        })

      assert settings.id
      assert settings.map_id == map.id
      assert settings.character_id == character.id
      assert settings.tracked == true
    end

    test "factory creates unique data for multiple records" do
      user1 = insert(:user)
      user2 = insert(:user)

      assert user1.id != user2.id
      assert user1.hash != user2.hash
      assert user1.name != user2.name

      char1 = insert(:character, %{user_id: user1.id})
      char2 = insert(:character, %{user_id: user2.id})

      assert char1.id != char2.id
      assert char1.eve_id != char2.eve_id
      assert char1.name != char2.name
    end

    test "factory respects provided attributes" do
      specific_name = "Specific Test Pilot"
      specific_eve_id = "123456789"

      user = insert(:user)

      character =
        insert(:character, %{
          user_id: user.id,
          name: specific_name,
          eve_id: specific_eve_id
        })

      assert character.name == specific_name
      assert character.eve_id == specific_eve_id
      assert character.user_id == user.id
    end

    test "creates data with relationships" do
      # Create a user with a character and map
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      # Create a tracking relationship
      settings =
        insert(:map_character_settings, %{
          map_id: map.id,
          character_id: character.id,
          tracked: true
        })

      # Verify relationships work
      assert settings.map_id == map.id
      assert settings.character_id == character.id

      # Test with systems and connections
      system1 = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      connection =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id
        })

      assert connection.map_id == map.id
      assert connection.solar_system_source == system1.solar_system_id
      assert connection.solar_system_target == system2.solar_system_id
    end
  end

  describe "Factory integration with database" do
    test "created records persist in database" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Verify records can be found in database
      found_user = WandererApp.Api.User.by_id!(user.id)
      found_character = WandererApp.Repo.get(WandererApp.Api.Character, character.id)

      assert found_user.id == user.id
      assert found_character.id == character.id
    end

    test "factory works with database constraints" do
      # Test that factory respects database constraints
      user = insert(:user)

      # Should be able to create multiple characters for same user
      char1 = insert(:character, %{user_id: user.id})
      char2 = insert(:character, %{user_id: user.id})

      assert char1.user_id == user.id
      assert char2.user_id == user.id
      assert char1.id != char2.id
    end
  end
end
