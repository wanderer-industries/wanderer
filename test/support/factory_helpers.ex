defmodule WandererApp.FactoryHelpers do
  @moduledoc """
  Helper functions for working with ExMachina factories in tests.

  This module provides utility functions for common test data creation patterns
  and cleanup operations to support the ExMachina-Ash factory implementation.
  """

  import WandererApp.Factory

  @doc """
  Cleanup test data by removing all created records.

  This is useful for ensuring test isolation when not using Ecto.Sandbox.
  """
  def cleanup_test_data do
    # Clean up in reverse dependency order
    Ash.bulk_destroy!(WandererApp.Api.MapConnection, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.MapSystem, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.MapAccessList, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.AccessListMember, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.AccessList, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.Map, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.Character, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(WandererApp.Api.User, :destroy, %{}, strategy: :stream)

    :ok
  end

  @doc """
  Create multiple systems for a map.

  ## Examples

      create_multiple_systems(map, 5, actor)
      create_multiple_systems(map, ["System A", "System B"], actor)
  """
  def create_multiple_systems(map, count_or_names, actor \\ nil)

  def create_multiple_systems(map, count, actor) when is_integer(count) do
    names = Enum.map(1..count, &"System #{&1}")
    create_multiple_systems(map, names, actor)
  end

  def create_multiple_systems(map, names, actor) when is_list(names) do
    Enum.map(names, fn name ->
      create_map_system(%{map: map, name: name}, actor)
    end)
  end

  @doc """
  Create connections between systems in a chain pattern.

  Creates connections: system1 -> system2 -> system3 -> ...
  """
  def create_system_chain(systems, actor \\ nil) do
    systems
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] ->
      create_map_connection(
        %{
          map: source.map,
          source_system: source,
          target_system: target
        },
        actor
      )
    end)
  end

  @doc """
  Create a star pattern of connections with one central system.

  Creates connections from the central system to all other systems.
  """
  def create_star_connections(central_system, outer_systems, actor \\ nil) do
    Enum.map(outer_systems, fn outer_system ->
      create_map_connection(
        %{
          map: central_system.map,
          source_system: central_system,
          target_system: outer_system
        },
        actor
      )
    end)
  end

  @doc """
  Create ACL members for an access list.

  ## Examples

      create_acl_members(acl, [
        %{member_type: "character", member_id: 123, role: "admin"},
        %{member_type: "corporation", member_id: 456, role: "viewer"}
      ], actor)
  """
  def create_acl_members(access_list, member_configs, actor \\ nil) do
    Enum.map(member_configs, fn config ->
      attrs = Map.merge(config, %{access_list: access_list})

      if actor do
        Ash.create!(WandererApp.Api.AccessListMember, attrs, actor: actor)
      else
        create_with_ash(attrs, WandererApp.Api.AccessListMember, :create)
      end
    end)
  end

  @doc """
  Associate multiple ACLs with a map.
  """
  def associate_acls_with_map(map, access_lists, actor \\ nil) do
    Enum.map(access_lists, fn acl ->
      attrs = %{map: map, access_list: acl}

      if actor do
        Ash.create!(WandererApp.Api.MapAccessList, attrs, actor: actor)
      else
        create_with_ash(attrs, WandererApp.Api.MapAccessList, :create)
      end
    end)
  end

  @doc """
  Create a complex map scenario for integration testing.

  Creates:
  - Map with API key
  - Multiple systems (5 by default)
  - Chain connections between systems
  - ACL with multiple members
  - Map-ACL association
  """
  def create_complex_map_scenario(attrs \\ %{}) do
    # Create base scenario
    scenario = create_authenticated_map_scenario(attrs)

    # Create systems
    system_count = attrs[:system_count] || 5
    systems = create_multiple_systems(scenario.map, system_count, scenario.character)

    # Create connections in chain pattern
    connections = create_system_chain(systems, scenario.character)

    # Create ACL with members
    acl =
      create_access_list(
        %{
          name: "Test ACL for #{scenario.map.name}",
          owner_id: scenario.character.id
        },
        scenario.character
      )

    # Add ACL members
    members =
      create_acl_members(
        acl,
        [
          %{member_type: "character", member_id: scenario.character.eve_id, role: "admin"},
          %{member_type: "corporation", member_id: "98000001", role: "viewer"}
        ],
        scenario.character
      )

    # Associate ACL with map
    map_acl = associate_acls_with_map(scenario.map, [acl], scenario.character)

    Map.merge(scenario, %{
      systems: systems,
      connections: connections,
      acl: acl,
      acl_members: members,
      map_acl: map_acl
    })
  end

  @doc """
  Create test data for API pagination testing.

  Creates multiple records of the specified type for testing pagination endpoints.
  """
  def create_pagination_test_data(type, count, attrs \\ %{}, actor \\ nil) do
    case type do
      :maps ->
        user = attrs[:user] || create_user()
        character = attrs[:character] || create_character(%{user_id: user.id}, user)

        Enum.map(1..count, fn i ->
          create_map(%{name: "Map #{i}"}, character)
        end)

      :systems ->
        map = attrs[:map] || raise "Map is required for systems"
        actor = actor || attrs[:actor] || raise "Actor is required for systems"

        Enum.map(1..count, fn i ->
          create_map_system(%{map: map, name: "System #{i}"}, actor)
        end)

      :access_lists ->
        user = attrs[:user] || create_user()
        character = attrs[:character] || create_character(%{user_id: user.id}, user)

        Enum.map(1..count, fn i ->
          create_access_list(%{name: "ACL #{i}"}, character)
        end)

      _ ->
        raise "Unsupported pagination test type: #{type}"
    end
  end

  @doc """
  Generate test API key for authentication.
  """
  def generate_test_api_key(prefix \\ "test") do
    "#{prefix}-api-key-#{System.unique_integer([:positive])}"
  end

  @doc """
  Generate test EVE character ID.
  """
  def generate_test_eve_id do
    # EVE character IDs start from 90000000
    90_000_000 + :rand.uniform(1_000_000)
  end

  @doc """
  Generate test EVE corporation ID.
  """
  def generate_test_corp_id do
    # EVE corporation IDs start from 98000000
    98_000_000 + :rand.uniform(100_000)
  end

  @doc """
  Generate test EVE alliance ID.
  """
  def generate_test_alliance_id do
    # EVE alliance IDs start from 99000000
    99_000_000 + :rand.uniform(10000)
  end

  # Private helpers

  defp create_with_ash(attrs, resource, action) do
    Ash.create!(resource, attrs, action: action)
  end
end
