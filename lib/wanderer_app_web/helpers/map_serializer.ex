defmodule WandererAppWeb.Helpers.MapSerializer do
  @moduledoc """
  Helper module for consistent map serialization in API responses.

  Ensures that:
  - Map slugs are used in URL generation
  - Map UUIDs are included in response payloads
  - Consistent structure across all map-related responses
  """

  alias WandererAppWeb.Helpers.ApiVersion

  @doc """
  Serializes a map for API response.

  Returns a map with both UUID (as 'id') and slug for identification,
  encouraging clients to use slugs in URLs while maintaining UUID availability.
  """
  def serialize_map(nil), do: nil

  def serialize_map(map) do
    %{
      # UUID for unique identification
      id: map.id,
      # Slug for URL usage
      slug: map.slug,
      name: map.name,
      description: map.description,
      scope: map.scope,
      owner_id: map.owner_id,
      created_at: map.inserted_at,
      updated_at: map.updated_at,
      # Include URL hint to encourage slug usage
      _links: %{
        self: ApiVersion.resource_path({:map, map.slug}),
        systems: ApiVersion.resource_path({:map_systems, map.slug}),
        connections: ApiVersion.resource_path({:map_connections, map.slug}),
        characters: ApiVersion.resource_path({:map_characters, map.slug})
      }
    }
  end

  @doc """
  Serializes a map for minimal/embedded contexts.
  """
  def serialize_map_minimal(nil), do: nil

  def serialize_map_minimal(map) do
    %{
      id: map.id,
      slug: map.slug,
      name: map.name
    }
  end

  @doc """
  Adds map reference to another resource.

  This ensures consistent map identification in nested resources.
  """
  def add_map_reference(data, map) when is_map(data) and is_map(map) do
    data
    |> Map.put(:map_id, map.id)
    |> Map.put(:map_slug, map.slug)
    |> Map.put(:map, serialize_map_minimal(map))
  end

  def add_map_reference(data, _), do: data

  @doc """
  Updates a URL to use slug instead of UUID if present.
  """
  def normalize_map_url(url, map) when is_binary(url) and is_map(map) do
    # Replace UUID with slug in URL if found
    String.replace(url, map.id, map.slug)
  end

  def normalize_map_url(url, _), do: url
end
