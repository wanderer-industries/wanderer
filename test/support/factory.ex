defmodule WandererAppWeb.Factory do
  @moduledoc """
  Test data factory for creating Ash resources in tests.

  This module provides functions to create test data for various
  resources in the application.
  """

  alias WandererApp.Api

  @doc """
  Main insert function that delegates to specific resource creators.
  Provides ExMachina-like interface for consistent test usage.
  """
  def insert(resource_type, attrs \\ %{})

  def insert(:user, attrs) do
    create_user(attrs)
  end

  def insert(:character, attrs) do
    create_character(attrs)
  end

  def insert(:map, attrs) do
    create_map(attrs)
  end

  def insert(:map_audit_event, attrs) do
    create_user_activity(attrs)
  end

  def insert(:map_system, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    attrs = Map.delete(attrs, :map_id)
    create_map_system(map_id, attrs)
  end

  def insert(:map_connection, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    attrs = Map.delete(attrs, :map_id)
    create_map_connection(map_id, attrs)
  end

  def insert(:access_list, attrs) do
    owner_id = Map.fetch!(attrs, :owner_id)
    attrs = Map.delete(attrs, :owner_id)
    create_access_list(owner_id, attrs)
  end

  def insert(:access_list_member, attrs) do
    access_list_id = Map.fetch!(attrs, :access_list_id)
    attrs = Map.delete(attrs, :access_list_id)
    create_access_list_member(access_list_id, attrs)
  end

  def insert(:map_access_list, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    access_list_id = Map.fetch!(attrs, :access_list_id)
    attrs = attrs |> Map.delete(:map_id) |> Map.delete(:access_list_id)
    create_map_access_list(map_id, access_list_id, attrs)
  end

  def insert(:map_system_signature, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    system_id = Map.fetch!(attrs, :solar_system_id)
    attrs = attrs |> Map.delete(:map_id) |> Map.delete(:solar_system_id)
    create_map_system_signature(map_id, system_id, attrs)
  end

  def insert(:map_system_structure, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    system_id = Map.fetch!(attrs, :solar_system_id)
    attrs = attrs |> Map.delete(:map_id) |> Map.delete(:solar_system_id)
    create_map_system_structure(map_id, system_id, attrs)
  end

  def insert(:license, attrs) do
    user_id = Map.fetch!(attrs, :user_id)
    attrs = Map.delete(attrs, :user_id)
    create_license(user_id, attrs)
  end

  def insert(:map_system_comment, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    system_id = Map.fetch!(attrs, :solar_system_id)
    character_id = Map.fetch!(attrs, :character_id)

    attrs =
      attrs |> Map.delete(:map_id) |> Map.delete(:solar_system_id) |> Map.delete(:character_id)

    create_map_system_comment(map_id, system_id, character_id, attrs)
  end

  def insert(:map_character_settings, attrs) do
    map_id = Map.fetch!(attrs, :map_id)
    character_id = Map.fetch!(attrs, :character_id)
    attrs = attrs |> Map.delete(:map_id) |> Map.delete(:character_id)
    create_map_character_settings(map_id, character_id, attrs)
  end

  def insert(resource_type, _attrs) do
    raise "Unknown factory resource type: #{resource_type}"
  end

  @doc """
  Creates a test user with reasonable defaults.
  """
  def build_user(attrs \\ %{}) do
    default_attrs = %{
      name: "Test User #{System.unique_integer([:positive])}",
      hash: "test_hash_#{System.unique_integer([:positive])}"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_user(attrs \\ %{}) do
    attrs = build_user(attrs)

    case Ash.create(Api.User, attrs) do
      {:ok, user} -> user
      {:error, reason} -> raise "Failed to create user: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a test character with reasonable defaults.
  """
  def build_character(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      eve_id: "#{2_000_000_000 + unique_id}",
      name: "Test Character #{unique_id}",
      access_token: "test_access_token_#{unique_id}",
      refresh_token: "test_refresh_token_#{unique_id}",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
      scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
      tracking_pool: "default"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_character(attrs \\ %{}) do
    attrs = build_character(attrs)
    {:ok, character} = Ash.create(Api.Character, attrs)
    character
  end

  @doc """
  Creates a test map with reasonable defaults.
  """
  def build_map(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      name: "Test Map #{unique_id}",
      slug: "test-map-#{unique_id}",
      description: "A test map for automated testing",
      scope: :none,
      only_tracked_characters: false,
      public_api_key: "test_api_key_#{unique_id}"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map(attrs \\ %{}) do
    # Build attrs with defaults
    built_attrs = build_map(attrs)

    # Extract public_api_key if provided, as it needs to be set separately
    {public_api_key, built_attrs} = Map.pop(built_attrs, :public_api_key)

    # Ensure we have an owner for the map
    owner =
      if built_attrs[:owner_id] do
        {:ok, owner} = Ash.get(Api.Character, built_attrs[:owner_id])
        owner
      else
        # Create a default owner if none provided
        create_character()
      end

    # Clean up attrs for creation
    create_attrs =
      built_attrs
      |> Map.delete(:owner_id)
      |> Map.put(:owner_id, owner.id)

    {:ok, map} = Ash.create(Api.Map, create_attrs, action: :new)

    # Always update with public_api_key if we have one (from defaults or provided)
    map =
      if public_api_key do
        {:ok, updated_map} = Api.Map.update_api_key(map, %{public_api_key: public_api_key})
        updated_map
      else
        map
      end

    map
  end

  @doc """
  Creates a test map system with reasonable defaults.
  """
  def build_map_system(attrs \\ %{}) do
    default_attrs = %{
      # Jita
      solar_system_id: 30_000_142,
      position_x: 100,
      position_y: 200,
      status: 0,
      visible: true,
      locked: false
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_system(map_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_system()
      |> Map.put(:map_id, map_id)

    {:ok, system} = Ash.create(Api.MapSystem, attrs)
    system
  end

  @doc """
  Creates a test map connection with reasonable defaults.
  """
  def build_map_connection(attrs \\ %{}) do
    default_attrs = %{
      # Jita
      solar_system_source: 30_000_142,
      # Dodixie
      solar_system_target: 30_002659,
      type: 0,
      mass_status: 0,
      time_status: 0,
      ship_size_type: 0,
      locked: false
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_connection(map_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_connection()
      |> Map.put(:map_id, map_id)

    {:ok, connection} = Ash.create(Api.MapConnection, attrs)
    connection
  end

  @doc """
  Creates a test access list with reasonable defaults.
  """
  def build_access_list(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      name: "Test ACL #{unique_id}",
      description: "A test access control list",
      api_key: "test_acl_key_#{unique_id}"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_access_list(owner_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_access_list()
      |> Map.put(:owner_id, owner_id)

    {:ok, acl} = Ash.create(Api.AccessList, attrs)
    acl
  end

  @doc """
  Creates a test access list member with reasonable defaults.
  """
  def build_access_list_member(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      eve_entity_id: "#{3_000_000_000 + unique_id}",
      eve_entity_name: "Test Entity #{unique_id}",
      eve_entity_category: "character",
      role: "viewer"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_access_list_member(access_list_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_access_list_member()
      |> Map.put(:access_list_id, access_list_id)

    {:ok, member} = Ash.create(Api.AccessListMember, attrs)
    member
  end

  @doc """
  Creates a test map access list association with reasonable defaults.
  """
  def build_map_access_list(attrs \\ %{}) do
    default_attrs = %{
      role: "viewer"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_access_list(map_id, access_list_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_access_list()
      |> Map.put(:map_id, map_id)
      |> Map.put(:access_list_id, access_list_id)

    {:ok, map_acl} = Ash.create(Api.MapAccessList, attrs)
    map_acl
  end

  @doc """
  Creates a test map system signature with reasonable defaults.
  """
  def build_map_system_signature(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      eve_id: "ABC-#{unique_id}",
      signature_type: "wormhole",
      name: "Test Signature #{unique_id}",
      description: "A test signature"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_system_signature(map_id, system_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_system_signature()
      |> Map.put(:map_id, map_id)
      |> Map.put(:solar_system_id, system_id)

    {:ok, signature} = Ash.create(Api.MapSystemSignature, attrs)
    signature
  end

  @doc """
  Creates a test map system structure with reasonable defaults.
  """
  def build_map_system_structure(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      structure_id: "#{1_000_000_000_000 + unique_id}",
      name: "Test Structure #{unique_id}",
      type_id: 35825,
      # Astrahus
      status: "anchored"
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_system_structure(map_id, system_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_system_structure()
      |> Map.put(:map_id, map_id)
      |> Map.put(:solar_system_id, system_id)

    {:ok, structure} = Ash.create(Api.MapSystemStructure, attrs)
    structure
  end

  @doc """
  Creates a test license with reasonable defaults.
  """
  def build_license(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      license_key: "test_license_#{unique_id}",
      license_type: "map",
      status: "active",
      expires_at: DateTime.utc_now() |> DateTime.add(30, :day)
    }

    Map.merge(default_attrs, attrs)
  end

  def create_license(user_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_license()
      |> Map.put(:user_id, user_id)

    {:ok, license} = Ash.create(Api.License, attrs)
    license
  end

  @doc """
  Creates a test map system comment with reasonable defaults.
  """
  def build_map_system_comment(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      text: "Test comment #{unique_id}",
      position_x: 150,
      position_y: 150
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_system_comment(map_id, system_id, character_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_system_comment()
      |> Map.put(:map_id, map_id)
      |> Map.put(:solar_system_id, system_id)
      |> Map.put(:character_id, character_id)

    {:ok, comment} = Ash.create(Api.MapSystemComment, attrs)
    comment
  end

  @doc """
  Creates a test map character settings with reasonable defaults.
  """
  def build_map_character_settings(attrs \\ %{}) do
    default_attrs = %{
      tracked: true,
      visible: true
    }

    Map.merge(default_attrs, attrs)
  end

  def create_map_character_settings(map_id, character_id, attrs \\ %{}) do
    attrs =
      attrs
      |> build_map_character_settings()
      |> Map.put(:map_id, map_id)
      |> Map.put(:character_id, character_id)

    {:ok, settings} = Ash.create(Api.MapCharacterSettings, attrs)
    settings
  end

  @doc """
  Creates test data for a complete map scenario:
  - User with character
  - Map with systems and connections
  - Access control lists
  """
  def create_test_scenario(opts \\ []) do
    # Create user and character
    user = create_user()
    character = create_character(%{user_id: user.id})

    # Create map
    map = create_map(%{owner_id: user.id})

    # Create systems if requested
    systems =
      if Keyword.get(opts, :with_systems, true) do
        [
          # Jita
          create_map_system(map.id, %{solar_system_id: 30_000_142}),
          # Dodixie
          create_map_system(map.id, %{solar_system_id: 30_002659})
        ]
      else
        []
      end

    # Create connections if requested and we have systems
    connections =
      if Keyword.get(opts, :with_connections, true) and length(systems) >= 2 do
        [jita, dodixie] = systems

        [
          create_map_connection(map.id, %{
            solar_system_source: jita.solar_system_id,
            solar_system_target: dodixie.solar_system_id
          })
        ]
      else
        []
      end

    # Create ACL if requested
    {acl, acl_member, map_acl} =
      if Keyword.get(opts, :with_acl, false) do
        acl = create_access_list(character.id)
        member = create_access_list_member(acl.id, %{eve_entity_id: character.eve_id})
        map_acl = create_map_access_list(map.id, acl.id)
        {acl, member, map_acl}
      else
        {nil, nil, nil}
      end

    # Create signatures if requested and we have systems
    signatures =
      if Keyword.get(opts, :with_signatures, false) and length(systems) > 0 do
        Enum.flat_map(systems, fn system ->
          [
            create_map_system_signature(map.id, system.solar_system_id, %{
              eve_id: "ABC-#{system.solar_system_id}",
              signature_type: "wormhole"
            })
          ]
        end)
      else
        []
      end

    # Create structures if requested and we have systems
    structures =
      if Keyword.get(opts, :with_structures, false) and length(systems) > 0 do
        [first_system | _] = systems

        [
          create_map_system_structure(map.id, first_system.solar_system_id, %{
            name: "Test Citadel",
            type_id: 35825
          })
        ]
      else
        []
      end

    # Create license if requested
    license =
      if Keyword.get(opts, :with_license, false) do
        create_license(user.id)
      else
        nil
      end

    # Create comments if requested and we have systems
    comments =
      if Keyword.get(opts, :with_comments, false) and length(systems) > 0 do
        [first_system | _] = systems

        [
          create_map_system_comment(map.id, first_system.solar_system_id, character.id, %{
            text: "This is a test comment"
          })
        ]
      else
        []
      end

    %{
      user: user,
      character: character,
      map: map,
      systems: systems,
      connections: connections,
      acl: acl,
      acl_member: acl_member,
      map_acl: map_acl,
      signatures: signatures,
      structures: structures,
      license: license,
      comments: comments
    }
  end

  @doc """
  Creates a test user activity (audit event) with reasonable defaults.
  """
  def build_user_activity(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      entity_id: Ecto.UUID.generate(),
      entity_type: "map",
      event_type: "test_event_#{unique_id}",
      event_data: %{"test" => "data"}
    }

    Map.merge(default_attrs, attrs)
  end

  def create_user_activity(attrs \\ %{}) do
    # Ensure we have a user_id
    if is_nil(Map.get(attrs, :user_id)) do
      raise ArgumentError, "user_id is required for creating user activity"
    end

    # Build attrs from defaults first, then apply overrides
    attrs =
      build_user_activity()
      |> Map.merge(attrs)

    # Convert event_data to JSON string if it's a map
    attrs =
      if is_map(attrs[:event_data]) and not is_binary(attrs[:event_data]) do
        Map.put(attrs, :event_data, Jason.encode!(attrs[:event_data]))
      else
        attrs
      end

    # Call the new function with all attributes including user_id and character_id
    case Api.UserActivity.new(attrs) do
      {:ok, activity} ->
        activity

      {:error, error} ->
        raise "Failed to create user activity: #{inspect(error)}"
    end
  end
end
