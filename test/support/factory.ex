defmodule WandererApp.Factory do
  @moduledoc """
  ExMachina factory for creating test data using Ash framework.

  This factory uses proper Ash resource actions instead of raw database inserts
  to ensure business rules and validations are properly enforced during test data creation.
  """

  use ExMachina

  alias WandererApp.Api.{
    User,
    Character,
    Map,
    AccessList,
    AccessListMember,
    MapSystem,
    MapConnection
  }

  @doc """
  Default user factory with actor-aware creation.
  """
  def user_factory do
    process_id =
      :erlang.pid_to_list(self()) |> List.to_string() |> String.replace(["<", ">", "."], "")

    %{
      name: sequence("User"),
      hash:
        sequence(:user_hash, &"user-hash-#{System.system_time(:microsecond)}-#{process_id}-#{&1}")
      # Additional user attributes can be added here
    }
  end

  @doc """
  Character factory linked to a user.
  """
  def character_factory do
    process_id =
      :erlang.pid_to_list(self()) |> List.to_string() |> String.replace(["<", ">", "."], "")

    %{
      eve_id: sequence(:eve_id, &"#{System.system_time(:microsecond)}#{process_id}#{&1}"),
      name: sequence("Character"),
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
      access_token: "test-access-token",
      refresh_token: "test-refresh-token",
      scopes: "esi-characters.read_blueprints.v1"
    }
  end

  @doc """
  Map factory with proper Ash resource creation.
  """
  def map_factory do
    %{
      name: sequence("Test Map"),
      slug: sequence(:map_slug, &"test-map-#{&1}"),
      description: "Test map description",
      scope: :wormholes
    }
  end

  @doc """
  Map with API key for authentication testing.
  """
  def map_with_api_key_factory do
    build(:map)
    |> Elixir.Map.merge(%{
      public_api_key: sequence(:api_key, &"map-api-key-#{&1}")
    })
  end

  @doc """
  Access list factory.
  """
  def access_list_factory do
    %{
      name: sequence("Test ACL"),
      description: "Test access control list"
    }
  end

  @doc """
  Access list with API key for authentication testing.
  """
  def access_list_with_api_key_factory do
    build(:access_list)
    |> Elixir.Map.merge(%{
      api_key: sequence(:acl_api_key, &"acl-api-key-#{&1}")
    })
  end

  @doc """
  Access list member factory.
  """
  def access_list_member_factory do
    %{
      access_list: build(:access_list),
      name: sequence("Member"),
      role: "member",
      eve_character_id: nil,
      eve_corporation_id: nil,
      eve_alliance_id: nil
    }
  end

  @doc """
  Map access list association factory.
  """
  def map_access_list_factory do
    %{
      map: build(:map),
      access_list: build(:access_list)
    }
  end

  @doc """
  Map system factory.
  """
  def map_system_factory do
    %{
      # Will be set when creating
      map_id: nil,
      solar_system_id: sequence(:solar_system_id, &(&1 + 30_000_001)),
      name: sequence("System"),
      position_x: :rand.uniform(1000),
      position_y: :rand.uniform(1000)
    }
  end

  @doc """
  Map connection factory.
  """
  def map_connection_factory do
    %{
      # Will be set when creating
      map_id: nil,
      # Will be set when creating
      solar_system_source: nil,
      # Will be set when creating
      solar_system_target: nil,
      # wormhole
      type: 0,
      # all ships
      ship_size_type: 1
      # Note: mass_status and time_status are not in default_accept list
      # They must be set using update actions after creation
    }
  end

  # Ash creation helpers

  @doc """
  Create a user using Ash.create!/2
  """
  def create_user(attrs \\ %{}) do
    :user
    |> build(attrs)
    |> create_with_ash(User, :create)
  end

  @doc """
  Create a character using Ash.create!/3 with actor
  """
  def create_character(attrs \\ %{}, actor \\ nil) do
    # Build character attributes as a map
    base_attrs = build(:character)
    character_attrs = Elixir.Map.merge(base_attrs, attrs)

    # Remove user_id from character_attrs as it's not accepted by :create action
    {user_id, character_attrs} = Elixir.Map.pop(character_attrs, :user_id)

    character =
      if actor do
        Ash.create!(Character, character_attrs, actor: actor, action: :create)
      else
        create_with_ash(character_attrs, Character, :create)
      end

    # If user_id was provided, assign the character to the user
    if user_id do
      Ash.update!(character, %{user_id: user_id}, action: :assign)
    else
      character
    end
  end

  @doc """
  Create a map using Ash.create!/3 with actor
  """
  def create_map(attrs \\ %{}, actor \\ nil) do
    map_attrs = build(:map, attrs)

    if actor do
      Ash.create!(Map, map_attrs, actor: actor, action: :new)
    else
      create_with_ash(map_attrs, Map, :new)
    end
  end

  @doc """
  Create an access list using Ash.create!/3 with actor
  """
  def create_access_list(attrs \\ %{}, actor \\ nil) do
    acl_attrs = build(:access_list, attrs)

    if actor do
      Ash.create!(AccessList, acl_attrs, actor: actor, action: :new)
    else
      create_with_ash(acl_attrs, AccessList, :new)
    end
  end

  @doc """
  Create a map system using Ash.create!/3 with actor
  """
  def create_map_system(attrs \\ %{}, actor \\ nil) do
    # Convert map to map_id if needed
    attrs =
      if attrs[:map] do
        attrs
        |> Elixir.Map.put(:map_id, attrs[:map].id)
        |> Elixir.Map.delete(:map)
      else
        attrs
      end

    # Separate attributes not accepted by create action
    {tag, attrs} = Elixir.Map.pop(attrs, :tag)
    {description, attrs} = Elixir.Map.pop(attrs, :description)
    {locked, attrs} = Elixir.Map.pop(attrs, :locked)
    {temporary_name, attrs} = Elixir.Map.pop(attrs, :temporary_name)
    {labels, attrs} = Elixir.Map.pop(attrs, :labels)
    {linked_sig_eve_id, attrs} = Elixir.Map.pop(attrs, :linked_sig_eve_id)
    {visible, attrs} = Elixir.Map.pop(attrs, :visible)
    {_custom_name, attrs} = Elixir.Map.pop(attrs, :custom_name)
    {_added_at, attrs} = Elixir.Map.pop(attrs, :added_at)

    system_attrs = build(:map_system, attrs)

    system =
      if actor do
        Ash.create!(MapSystem, system_attrs, actor: actor)
      else
        create_with_ash(system_attrs, MapSystem, :create)
      end

    # Add system to cache to support connection creation in tests
    system_static_info = %{
      solar_system_id: system.solar_system_id,
      solar_system_name: system.name,
      system_class: 0,
      security: 0.5,
      region_id: 10_000_001,
      constellation_id: 20_000_001
    }

    Cachex.put(:system_static_info_cache, system.solar_system_id, system_static_info)

    # Also add to map server mock if map server is mocked
    if WandererApp.Test.MapServerMock.is_map_started?(system.map_id) do
      WandererApp.Test.MapServerMock.add_system_to_map(system.map_id, system)
    end

    # Update with attributes not accepted by create action
    system =
      if tag do
        Ash.update!(system, %{tag: tag}, action: :update_tag)
      else
        system
      end

    system =
      if description do
        Ash.update!(system, %{description: description}, action: :update_description)
      else
        system
      end

    system =
      if locked do
        Ash.update!(system, %{locked: locked}, action: :update_locked)
      else
        system
      end

    system =
      if temporary_name do
        Ash.update!(system, %{temporary_name: temporary_name}, action: :update_temporary_name)
      else
        system
      end

    system =
      if labels do
        Ash.update!(system, %{labels: labels}, action: :update_labels)
      else
        system
      end

    system =
      if linked_sig_eve_id do
        Ash.update!(system, %{linked_sig_eve_id: linked_sig_eve_id},
          action: :update_linked_sig_eve_id
        )
      else
        system
      end

    system =
      if visible != nil do
        Ash.update!(system, %{visible: visible}, action: :update_visible)
      else
        system
      end

    # Note: custom_name and added_at don't have specific update actions
    # so they'll be skipped if provided

    system
  end

  @doc """
  Create a map connection using Ash.create!/3 with actor
  """
  def create_map_connection(attrs \\ %{}, actor \\ nil) do
    # Convert relationships to appropriate IDs
    attrs =
      attrs
      |> convert_map_to_id()
      |> convert_systems_for_connection()

    # Separate accepted attributes from those requiring update actions
    {mass_status, attrs} = Elixir.Map.pop(attrs, :mass_status)
    {time_status, attrs} = Elixir.Map.pop(attrs, :time_status)
    {locked, attrs} = Elixir.Map.pop(attrs, :locked)
    {custom_info, attrs} = Elixir.Map.pop(attrs, :custom_info)
    {wormhole_type, attrs} = Elixir.Map.pop(attrs, :wormhole_type)

    connection_attrs = build(:map_connection, attrs)

    connection =
      if actor do
        Ash.create!(MapConnection, connection_attrs, actor: actor)
      else
        create_with_ash(connection_attrs, MapConnection, :create)
      end

    # Update with attributes not accepted by create action
    connection =
      if mass_status do
        Ash.update!(connection, %{mass_status: mass_status}, action: :update_mass_status)
      else
        connection
      end

    connection =
      if time_status do
        Ash.update!(connection, %{time_status: time_status}, action: :update_time_status)
      else
        connection
      end

    connection =
      if locked do
        Ash.update!(connection, %{locked: locked}, action: :update_locked)
      else
        connection
      end

    connection =
      if custom_info do
        Ash.update!(connection, %{custom_info: custom_info}, action: :update_custom_info)
      else
        connection
      end

    connection =
      if wormhole_type do
        Ash.update!(connection, %{wormhole_type: wormhole_type}, action: :update_wormhole_type)
      else
        connection
      end

    # Update map cache with the connection
    map_id = connection.map_id

    # Use map server mock if available, otherwise update cache directly
    if WandererApp.Test.MapServerMock.is_map_started?(map_id) do
      WandererApp.Test.MapServerMock.add_connection_to_map(map_id, connection)
    else
      # Fallback to direct cache update for non-mocked tests
      case Cachex.get(:map_cache, map_id) do
        {:ok, map} when is_map(map) ->
          connection_key = "#{connection.solar_system_source}_#{connection.solar_system_target}"

          connection_data = %{
            id: connection.id,
            map_id: connection.map_id,
            solar_system_source: connection.solar_system_source,
            solar_system_target: connection.solar_system_target,
            type: connection.type,
            ship_size_type: connection.ship_size_type,
            mass_status: connection.mass_status || 0,
            time_status: connection.time_status || 0,
            locked: connection.locked || false
          }

          updated_connections =
            Elixir.Map.put(map.connections || %{}, connection_key, connection_data)

          updated_map = Elixir.Map.put(map, :connections, updated_connections)
          Cachex.put(:map_cache, map_id, updated_map)

        _ ->
          # If map not in cache, initialize it
          map_struct = %{
            map_id: map_id,
            connections: %{
              "#{connection.solar_system_source}_#{connection.solar_system_target}" => %{
                id: connection.id,
                map_id: connection.map_id,
                solar_system_source: connection.solar_system_source,
                solar_system_target: connection.solar_system_target,
                type: connection.type,
                ship_size_type: connection.ship_size_type,
                mass_status: connection.mass_status || 0,
                time_status: connection.time_status || 0,
                locked: connection.locked || false
              }
            },
            systems: %{}
          }

          Cachex.put(:map_cache, map_id, map_struct)
      end
    end

    connection
  end

  # High-level scenario helpers

  @doc """
  Creates a complete test scenario with authenticated map.

  Returns:
  - user: Created user
  - character: Created character
  - map: Created map with API key
  - api_key: API key for authentication
  """
  def create_authenticated_map_scenario(attrs \\ %{}) do
    user = create_user(attrs[:user] || %{})
    character = create_character(attrs[:character] || %{user_id: user.id}, user)
    map = create_map(attrs[:map] || %{owner_id: character.id}, character)

    # Update map with API key
    api_key = "api-key-#{System.unique_integer([:positive])}"

    {:ok, map} =
      Ash.update(map, %{public_api_key: api_key}, actor: character, action: :update_api_key)

    # Map server operations will be mocked in test environment
    # Also ensure map is in cache for connection listing
    map_struct = %{
      map_id: map.id,
      connections: %{},
      systems: %{}
    }

    Cachex.put(:map_cache, map.id, map_struct)

    %{
      user: user,
      character: character,
      map: map,
      api_key: map.public_api_key
    }
  end

  @doc """
  Creates a complete test scenario with authenticated ACL.

  Returns:
  - user: Created user
  - character: Created character  
  - access_list: Created ACL with API key
  - api_key: API key for authentication
  """
  def create_authenticated_acl_scenario(attrs \\ %{}) do
    user = create_user(attrs[:user] || %{})
    character = create_character(attrs[:character] || %{user_id: user.id}, user)
    access_list = create_access_list(attrs[:access_list] || %{owner_id: character.id}, character)

    %{
      user: user,
      character: character,
      access_list: access_list,
      api_key: access_list.api_key
    }
  end

  @doc """
  Creates a map with systems and connections for testing.
  """
  def create_map_with_systems_and_connections(attrs \\ %{}) do
    scenario = create_authenticated_map_scenario(attrs)

    # Create systems
    system1 =
      create_map_system(
        %{map: scenario.map, name: "System 1", solar_system_id: 30_000_001},
        scenario.character
      )

    system2 =
      create_map_system(
        %{map: scenario.map, name: "System 2", solar_system_id: 30_000_002},
        scenario.character
      )

    system3 =
      create_map_system(
        %{map: scenario.map, name: "System 3", solar_system_id: 30_000_003},
        scenario.character
      )

    # Create connections
    connection1 =
      create_map_connection(
        %{
          map: scenario.map,
          source_system: system1,
          target_system: system2
        },
        scenario.character
      )

    connection2 =
      create_map_connection(
        %{
          map: scenario.map,
          source_system: system2,
          target_system: system3
        },
        scenario.character
      )

    Elixir.Map.merge(scenario, %{
      systems: [system1, system2, system3],
      connections: [connection1, connection2]
    })
  end

  # Private helpers

  defp create_with_ash(attrs, resource, action) do
    Ash.create!(resource, attrs, action: action)
  end

  defp convert_to_id(attrs, relationship_key, id_key) do
    if attrs[relationship_key] do
      attrs
      |> Elixir.Map.put(id_key, attrs[relationship_key].id)
      |> Elixir.Map.delete(relationship_key)
    else
      attrs
    end
  end

  defp convert_map_to_id(attrs) do
    if attrs[:map] do
      attrs
      |> Elixir.Map.put(:map_id, attrs[:map].id)
      |> Elixir.Map.delete(:map)
    else
      attrs
    end
  end

  defp convert_systems_for_connection(attrs) do
    attrs =
      if attrs[:source_system] do
        attrs
        |> Elixir.Map.put(:solar_system_source, attrs[:source_system].solar_system_id)
        |> Elixir.Map.delete(:source_system)
      else
        attrs
      end

    attrs =
      if attrs[:target_system] do
        attrs
        |> Elixir.Map.put(:solar_system_target, attrs[:target_system].solar_system_id)
        |> Elixir.Map.delete(:target_system)
      else
        attrs
      end

    attrs
  end

  # Helper function to create ACL members
  def create_acl_member(attrs, actor \\ nil) do
    access_list = attrs[:access_list]
    access_list_id = access_list.id

    # Remove owner relationship and use owner_id instead
    {_owner, attrs} = Elixir.Map.pop(attrs, :owner)

    member_attrs =
      build(:access_list_member)
      |> Elixir.Map.merge(attrs)
      |> Elixir.Map.put(:access_list_id, access_list_id)
      |> Elixir.Map.drop([:access_list])

    Ash.create!(AccessListMember, member_attrs,
      actor: actor || access_list.owner,
      action: :create
    )
  end

  # Use ExMachina's built-in sequence functions directly

  @doc """
  Creates a test map with API authentication, compatible with TestFactory interface.
  Returns a map containing the created map data and API key.
  """
  def setup_test_map_with_auth(attrs \\ %{}) do
    # Create user
    user = create_user(attrs[:user] || %{})

    # Create character owned by user
    character =
      create_character(Elixir.Map.merge(%{user_id: user.id}, attrs[:character] || %{}), user)

    # Create map first
    map_base_attrs = build(:map)

    map_attrs =
      map_base_attrs
      |> Elixir.Map.merge(%{owner_id: character.id})
      |> Elixir.Map.merge(attrs[:map] || %{})

    # Create the map first without API key
    map =
      Map
      |> Ash.Changeset.for_create(:new, map_attrs, actor: character)
      |> Ash.create!()

    # Generate and set API key directly on the map struct for testing
    # This bypasses the policy system but allows tests to work
    api_key = "api-key-#{System.unique_integer([:positive])}"

    # Update the map directly in the database for testing
    updated_map = WandererApp.Repo.update!(Ecto.Changeset.change(map, public_api_key: api_key))

    # Use the struct with the API key set
    map = %{updated_map | public_api_key: api_key}

    # Setup map server mock for testing
    WandererApp.Test.MapServerMock.setup_map_mock(map.id)

    %{
      owner: character,
      user: user,
      map: map,
      map_id: map.id,
      map_slug: map.slug,
      # Use our generated key for tests
      api_key: api_key
    }
  end

  @doc """
  Creates a test ACL with API authentication, compatible with TestFactory interface.
  """
  def setup_test_acl_with_auth(attrs \\ %{}) do
    # Create character - either use provided character or create new one
    {character, user} =
      case attrs[:character] do
        %WandererApp.Api.Character{} = existing_character ->
          # Character already exists, use it (get the user from the character)
          user =
            if existing_character.user_id do
              Ash.get!(WandererApp.Api.User, existing_character.user_id)
            else
              create_user(attrs[:user] || %{})
            end

          {existing_character, user}

        character_attrs when is_map(character_attrs) ->
          # Create new character with provided attributes
          user = create_user(attrs[:user] || %{})

          character =
            create_character(Elixir.Map.merge(%{user_id: user.id}, character_attrs), user)

          {character, user}

        _ ->
          # Create default character
          user = create_user(attrs[:user] || %{})
          character = create_character(%{user_id: user.id}, user)
          {character, user}
      end

    # Create ACL with API key
    api_key = "acl-api-key-#{System.unique_integer([:positive])}"

    default_acl_attrs = %{
      name: "Test ACL #{System.unique_integer([:positive])}",
      description: "Test access control list",
      owner_id: character.id,
      api_key: api_key
    }

    acl_attrs = Elixir.Map.merge(default_acl_attrs, attrs[:acl] || %{})

    # Convert owner to owner_id if provided
    acl_attrs =
      case Elixir.Map.get(acl_attrs, :owner) do
        %WandererApp.Api.Character{id: owner_id} ->
          acl_attrs |> Elixir.Map.delete(:owner) |> Elixir.Map.put(:owner_id, owner_id)

        _ ->
          acl_attrs
      end

    acl = Ash.create!(AccessList, acl_attrs, actor: character, action: :new)

    %{
      owner: character,
      user: user,
      acl: acl,
      acl_id: acl.id,
      api_key: acl.api_key
    }
  end

  @doc """
  Creates a map with a valid API key using Ash.

  This ensures the map has a properly set public_api_key for testing.

  ## Examples

      map = create_map_with_api_key()
      map = create_map_with_api_key(%{name: "Custom Map"})
      map = create_map_with_api_key(%{}, character)  # With actor
  """
  def create_map_with_api_key(attrs \\ %{}, actor \\ nil) do
    # Generate a unique API key
    api_key = "map-api-key-#{System.unique_integer([:positive])}"

    # Create the map first
    map = create_map(attrs, actor)

    # Update with API key
    if actor do
      Ash.update!(map, %{public_api_key: api_key}, actor: actor, action: :update_api_key)
    else
      # Direct update if no actor
      map
      |> Ecto.Changeset.change(public_api_key: api_key)
      |> WandererApp.Repo.update!()
    end
  end

  @doc """
  Creates an access list with a valid API key using Ash.

  This ensures the ACL has a properly set api_key for testing.

  ## Examples

      acl = create_access_list_with_api_key()
      acl = create_access_list_with_api_key(%{name: "Custom ACL"})
      acl = create_access_list_with_api_key(%{}, character)  # With actor
  """
  def create_access_list_with_api_key(attrs \\ %{}, actor \\ nil) do
    # Generate a unique API key
    api_key = "acl-api-key-#{System.unique_integer([:positive])}"

    # Merge API key into attrs
    attrs_with_key = Map.put(attrs, :api_key, api_key)

    # Create the ACL with API key
    create_access_list(attrs_with_key, actor)
  end

  @doc """
  Creates a complete test setup with authenticated resources.

  Returns a map with:
  - :user - User with JWT token
  - :character - Character with JWT token  
  - :map - Map with API key
  - :acl - ACL with API key
  - :tokens - Map of all authentication tokens

  ## Examples

      setup = create_auth_test_setup()
      conn |> put_req_header("authorization", "Bearer " <> setup.tokens.map_api_key)
  """
  def create_auth_test_setup(attrs \\ %{}) do
    user = create_user(attrs[:user] || %{})
    character = create_character(Map.merge(%{user_id: user.id}, attrs[:character] || %{}))

    map =
      create_map_with_api_key(Map.merge(%{owner_id: character.id}, attrs[:map] || %{}), character)

    acl = create_access_list_with_api_key(attrs[:acl] || %{}, character)

    # Generate tokens
    user_token = WandererApp.Test.AuthHelpers.generate_jwt_token(user)
    character_token = WandererApp.Test.AuthHelpers.generate_character_token(character)

    %{
      user: user,
      character: character,
      map: map,
      acl: acl,
      tokens: %{
        user_jwt: user_token,
        character_jwt: character_token,
        map_api_key: map.public_api_key,
        acl_api_key: acl.api_key
      }
    }
  end
end
