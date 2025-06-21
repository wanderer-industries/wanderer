defmodule WandererAppWeb.Plugs.ResolveMapIdentifier do
  @moduledoc """
  Plug to resolve map identifiers (UUID or slug) to the actual map record.

  This plug:
  - Accepts both UUIDs and slugs in the :map_identifier parameter
  - Resolves them to the actual map record
  - Stores the map in conn.assigns for use in controllers
  - Ensures consistent usage of slugs in URLs
  """

  import Plug.Conn

  alias WandererApp.Api.Map, as: MapApi
  alias WandererAppWeb.Helpers.APIUtils

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_map_identifier(conn) do
      {:ok, identifier} ->
        resolve_and_assign_map(conn, identifier)

      :no_identifier ->
        # No map identifier in path, continue without assigning
        conn

      {:error, message} ->
        conn
        |> APIUtils.error_response(:bad_request, message)
        |> halt()
    end
  end

  defp get_map_identifier(conn) do
    case conn.path_params do
      %{"map_identifier" => identifier} when is_binary(identifier) and identifier != "" ->
        {:ok, identifier}

      %{"map_identifier" => _} ->
        {:error, "Invalid map identifier"}

      _ ->
        # For legacy routes, check query params
        get_map_identifier_from_query(conn)
    end
  end

  defp get_map_identifier_from_query(conn) do
    conn = Plug.Conn.fetch_query_params(conn)

    cond do
      # Check for map_id in query params
      map_id = conn.query_params["map_id"] ->
        if is_binary(map_id) and map_id != "" do
          {:ok, map_id}
        else
          {:error, "Invalid map_id parameter"}
        end

      # Check for slug in query params
      slug = conn.query_params["slug"] ->
        if is_binary(slug) and slug != "" do
          {:ok, slug}
        else
          {:error, "Invalid slug parameter"}
        end

      true ->
        :no_identifier
    end
  end

  defp resolve_and_assign_map(conn, identifier) do
    # First try to parse as UUID
    case Ecto.UUID.cast(identifier) do
      {:ok, uuid} ->
        # It's a valid UUID, fetch by ID
        case MapApi.by_id(uuid) do
          {:ok, map} ->
            assign_map_data(conn, map)

          {:error, _} ->
            handle_not_found(conn, "Map not found with ID: #{uuid}")
        end

      :error ->
        # Not a UUID, try as slug
        case MapApi.get_map_by_slug(identifier) do
          {:ok, map} ->
            assign_map_data(conn, map)

          {:error, _} ->
            handle_not_found(conn, "Map not found with slug: #{identifier}")
        end
    end
  end

  defp assign_map_data(conn, map) do
    conn
    |> assign(:map, map)
    |> assign(:map_id, map.id)
    |> assign(:map_slug, map.slug)
  end

  defp handle_not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> APIUtils.error_response(:not_found, message)
    |> halt()
  end
end
