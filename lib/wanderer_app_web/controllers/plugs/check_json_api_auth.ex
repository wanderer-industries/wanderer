defmodule WandererAppWeb.Plugs.CheckJsonApiAuth do
  @moduledoc """
  Plug for authenticating JSON:API v1 endpoints.

  Supports both session-based authentication (for web clients) and
  Bearer token authentication (for API clients).

  Currently, Bearer token authentication only supports map API keys.
  When a valid map API key is provided, the map owner is set as the
  authenticated user and the map is made available in conn.assigns.

  """

  import Plug.Conn

  alias Plug.Crypto
  alias WandererApp.Api.User
  alias WandererApp.SecurityAudit
  alias WandererApp.Audit.RequestContext

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

      {:error, reason} when is_binary(reason) ->
        # Legacy error handling for simple string errors
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

      {:error, external_message, internal_reason} ->
        # New error handling with separate internal and external messages
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log failed authentication with detailed internal reason
        request_details = extract_request_details(conn)

        SecurityAudit.log_auth_event(
          :auth_failure,
          nil,
          Map.merge(request_details, %{
            failure_reason: internal_reason,
            external_message: external_message
          })
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
        |> send_resp(401, Jason.encode!(%{error: external_message}))
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
        validate_api_token(conn, token)

      _ ->
        {:error, "Missing or invalid authorization header"}
    end
  end

  defp validate_api_token(conn, token) do
    # Check for map identifier in path params
    # According to PR feedback, routes supply params["map_identifier"]
    case conn.params["map_identifier"] do
      nil ->
        # No map identifier in path - this might be a general API endpoint
        # For now, we'll return an error since we need to validate against a specific map
        {:error, "Authentication failed", :no_map_context}

      identifier ->
        # Resolve the identifier (could be UUID or slug)
        case resolve_map_identifier(identifier) do
          {:ok, map} ->
            # Validate the token matches this specific map's API key
            if is_binary(map.public_api_key) &&
                 Crypto.secure_compare(map.public_api_key, token) do
              # Get the map owner
              case User.by_id(map.owner.user_id, load: :characters) do
                {:ok, user} ->
                  {:ok, user, map}

                {:error, _error} ->
                  {:error, "Authentication failed", :map_owner_not_found}
              end
            else
              {:error, "Authentication failed", :invalid_token_for_map}
            end

          {:error, _} ->
            {:error, "Authentication failed", :map_not_found}
        end
    end
  end

  # Helper to resolve map by ID or slug
  defp resolve_map_identifier(identifier) do
    # Try as UUID first
    case WandererApp.Api.Map.by_id(identifier, load: :owner) do
      {:ok, map} ->
        {:ok, map}

      _ ->
        # Try as slug
        WandererApp.Api.Map.get_map_by_slug(identifier, load: :owner)
    end
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
    RequestContext.build_request_details(conn)
    |> Map.put(:auth_method, get_auth_type(conn))
  end

  defp maybe_assign_map(conn, nil), do: conn

  defp maybe_assign_map(conn, map) do
    conn
    |> assign(:map, map)
    |> assign(:map_id, map.id)
  end
end
