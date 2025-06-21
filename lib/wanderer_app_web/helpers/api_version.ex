defmodule WandererAppWeb.Helpers.ApiVersion do
  @moduledoc """
  Centralized API version configuration and path helpers.
  
  This module provides helpers for generating versioned API paths
  without hardcoding the version throughout the codebase.
  """

  @default_version "v1"
  @supported_versions ["v1", "v2"]

  @doc """
  Returns the current default API version.
  """
  def current_version, do: @default_version

  @doc """
  Returns a list of supported API versions.
  """
  def supported_versions, do: @supported_versions

  @doc """
  Generates a versioned API path.
  
  ## Examples
  
      iex> api_path("/maps")
      "/api/v1/maps"
      
      iex> api_path("/maps", "v2")
      "/api/v2/maps"
  """
  def api_path(path, version \\ nil) do
    version = version || current_version()
    "/api/#{version}#{path}"
  end

  @doc """
  Generates versioned API paths for common resources.
  
  ## Examples
  
      iex> resource_path(:maps)
      "/api/v1/maps"
      
      iex> resource_path({:map, "my-map"})
      "/api/v1/maps/my-map"
      
      iex> resource_path({:map_systems, "my-map"})
      "/api/v1/maps/my-map/systems"
  """
  def resource_path(resource, version \\ nil) do
    version = version || current_version()
    base = "/api/#{version}"
    
    case resource do
      :maps -> 
        "#{base}/maps"
      
      {:map, slug} when is_binary(slug) -> 
        "#{base}/maps/#{slug}"
      
      {:map_systems, slug} when is_binary(slug) -> 
        "#{base}/maps/#{slug}/systems"
      
      {:map_connections, slug} when is_binary(slug) -> 
        "#{base}/maps/#{slug}/connections"
      
      {:map_characters, slug} when is_binary(slug) -> 
        "#{base}/maps/#{slug}/characters"
      
      {:acl, id} when is_binary(id) -> 
        "#{base}/acls/#{id}"
      
      {:acl_members, id} when is_binary(id) -> 
        "#{base}/acls/#{id}/members"
      
      _ -> 
        raise ArgumentError, "Unknown resource: #{inspect(resource)}"
    end
  end
end