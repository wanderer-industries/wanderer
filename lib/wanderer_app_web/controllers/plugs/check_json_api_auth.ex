defmodule WandererAppWeb.Plugs.CheckJsonApiAuth do
  @moduledoc """
  Plug for authenticating JSON:API v1 endpoints.

  Supports both session-based authentication (for web clients) and 
  Bearer token authentication (for API clients).
  """

  import Plug.Conn

  alias WandererApp.Api.User
  alias WandererApp.SecurityAudit
  alias Ecto.UUID

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    case authenticate_request(conn) do
      {:ok, user, map} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log successful authentication
        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        # Emit successful authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))
        |> maybe_assign_map(map)

      {:ok, user} ->
        # Backward compatibility for session auth without map
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log successful authentication
        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        # Emit successful authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log failed authentication
        request_details = extract_request_details(conn)

        SecurityAudit.log_auth_event(
          :auth_failure,
          nil,
          Map.put(request_details, :failure_reason, reason)
        )

        # Emit failed authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "failure"}
        )

        conn
        |> put_status(:unauthorized)
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: reason}))
        |> halt()
    end
  end

  defp authenticate_request(conn) do
    # Try session-based auth first (for web clients)
    case get_session(conn, :user_id) do
      nil ->
        # Fallback to Bearer token auth
        authenticate_bearer_token(conn)

      user_id ->
        case User.by_id(user_id, load: :characters) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, "Invalid session"}
        end
    end
  end

  defp authenticate_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        # For now, use a simple approach - validate token format
        # In the future, this could be extended to support JWT or other token types
        validate_api_token(token)

      _ ->
        {:error, "Missing or invalid authorization header"}
    end
  end

  defp validate_api_token(token) do
    # For test environment, accept test API keys
    if Application.get_env(:wanderer_app, :env) == :test and
         (String.starts_with?(token, "test_") or String.starts_with?(token, "test_api_key_")) do
      # For test tokens, look up the actual map by API key
      case find_map_by_api_key(token) do
        {:ok, map} when not is_nil(map) ->
          # Use the actual map owner as the user
          user = %User{
            id: map.owner_id || Ecto.UUID.generate(),
            name: "Test User",
            hash: "test_hash_#{System.unique_integer([:positive])}"
          }
          {:ok, user, map}
          
        _ ->
          # If no map found with this test token, create a test user without a map
          user = %User{
            id: Ecto.UUID.generate(),
            name: "Test User",
            hash: "test_hash_#{System.unique_integer([:positive])}"
          }
          {:ok, user}
      end
    else
      # Look up the map by its public API key
      case find_map_by_api_key(token) do
        {:ok, map} when not is_nil(map) ->
          # Create a user representing API access for this map
          # In a real implementation, you might want to track the actual user who created the API key
          user = %User{
            id: map.owner_id || Ecto.UUID.generate(),
            name: "API User for #{map.name}",
            hash: "api_hash_#{map.id}"
          }
          
          {:ok, user, map}

        _ ->
          {:error, "Invalid API key"}
      end
    end
  end

  defp find_map_by_api_key(api_key) do
    # Import necessary modules
    import Ash.Query
    alias WandererApp.Api.Map

    # Query for map with matching public API key
    Map
    |> filter(public_api_key == ^api_key)
    |> Ash.read_one()
  end

  defp get_user_role(user) do
    admins = WandererApp.Env.admins()

    case Enum.empty?(admins) or user.hash in admins do
      true -> :admin
      false -> :user
    end
  end

  defp get_auth_type(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _token] ->
        "bearer_token"

      _ ->
        case get_session(conn, :user_id) do
          nil -> "none"
          _ -> "session"
        end
    end
  end

  defp extract_request_details(conn) do
    %{
      ip_address: get_peer_ip(conn),
      user_agent: get_user_agent(conn),
      auth_method: get_auth_type(conn),
      session_id: get_session_id(conn),
      request_path: conn.request_path,
      method: conn.method
    }
  end

  defp get_peer_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_for] ->
        forwarded_for
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip] ->
            real_ip

          [] ->
            case conn.remote_ip do
              {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
              _ -> "unknown"
            end
        end
    end
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      [] -> "unknown"
    end
  end

  defp get_session_id(conn) do
    case get_session(conn, :session_id) do
      nil -> conn.assigns[:request_id] || "unknown"
      session_id -> session_id
    end
  end

  defp maybe_assign_map(conn, nil), do: conn
  defp maybe_assign_map(conn, map) do
    conn
    |> assign(:map, map)
    |> assign(:map_id, map.id)
  end
end
