defmodule WandererAppWeb.Plugs.ConditionalAssignMapOwner do
  @moduledoc """
  Conditionally assigns map owner information to conn.assigns for V1 API routes.

  This plug enables PubSub broadcasting for map operations by ensuring owner_character_id
  and owner_user_id are available when map context exists.

  Unlike the standard :api_map pipeline plugs (CheckMapApiKey, CheckMapSubscription),
  this plug does NOT halt the request if map context is missing, making it safe to use
  for both map-specific and user-level resources.

  Map context detection (in order of priority):
  1. conn.assigns[:map_id] - Set by CheckJsonApiAuth for Bearer token requests with map_identifier
  2. filter[map_id] - JSON:API filter parameter for map-specific queries
  3. Request body map_id - For create/update operations on map resources

  If no map context is found, the plug simply continues without setting owner fields.
  This allows user-level resources (AccessList, UserActivity, etc.) to work normally.
  """

  import Plug.Conn

  alias WandererApp.Map.Operations

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_map_id(conn) do
      {:ok, map_id} ->
        # Map context found - fetch and assign owner information
        case Operations.get_owner_character_id(map_id) do
          {:ok, %{id: char_id, user_id: user_id}} ->
            conn
            |> assign(:map_id, map_id)
            |> assign(:owner_character_id, char_id)
            |> assign(:owner_user_id, user_id)

          _ ->
            # Map exists but owner not found - set nil values
            conn
            |> assign(:map_id, map_id)
            |> assign(:owner_character_id, nil)
            |> assign(:owner_user_id, nil)
        end

      :no_map_context ->
        # No map context - this is okay for user-level resources
        # Don't halt, just continue without setting map fields
        conn
    end
  end

  # Try to extract map_id from various sources
  defp get_map_id(conn) do
    # 1. Check if already set by CheckJsonApiAuth (Bearer token with map_identifier)
    case conn.assigns[:map_id] do
      map_id when is_binary(map_id) and map_id != "" ->
        {:ok, map_id}

      _ ->
        # 2. Check JSON:API filter parameters (e.g., filter[map_id]=uuid)
        case get_filter_map_id(conn) do
          {:ok, map_id} -> {:ok, map_id}
          :not_found -> check_body_map_id(conn)
        end
    end
  end

  # Extract map_id from JSON:API filter parameters
  defp get_filter_map_id(conn) do
    # JSON:API filters come as filter[map_id]=value
    case conn.params do
      %{"filter" => %{"map_id" => map_id}} when is_binary(map_id) and map_id != "" ->
        {:ok, map_id}

      _ ->
        :not_found
    end
  end

  # Extract map_id from request body (for create/update operations)
  defp check_body_map_id(conn) do
    case conn.body_params do
      %{"data" => %{"attributes" => %{"map_id" => map_id}}}
      when is_binary(map_id) and map_id != "" ->
        {:ok, map_id}

      %{"data" => %{"relationships" => %{"map" => %{"data" => %{"id" => map_id}}}}}
      when is_binary(map_id) and map_id != "" ->
        {:ok, map_id}

      # Also check flat params for non-JSON:API formatted requests
      %{"map_id" => map_id} when is_binary(map_id) and map_id != "" ->
        {:ok, map_id}

      _ ->
        :no_map_context
    end
  end
end
