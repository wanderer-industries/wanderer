defmodule WandererAppWeb.Plugs.CheckJsonApiAuth do
  @moduledoc """
  Plug for authenticating JSON:API v1 endpoints.

  Supports both session-based authentication (for web clients) and
  Bearer token authentication (for API clients).

  ## Authentication Mode

  ### Token-Only Authentication (Simplified)
  All V1 API endpoints now use token-only authentication:
  - `Authorization: Bearer <token>` header identifies both the user and the map
  - No need to provide `map_id` or `map_identifier` in requests
  - The map context is automatically determined from the token

  ### Non-Map-Scoped Endpoints
  Some utility endpoints don't require map context:
  - OpenAPI/JSON Schema endpoints
  - Health check endpoints

  This simplified approach eliminates redundant map identification and
  ensures clients cannot accidentally access the wrong map.
  """

  import Plug.Conn
  require Logger

  alias WandererApp.Api.User
  alias WandererApp.Api.ActorWithMap
  alias WandererApp.SecurityAudit
  alias WandererApp.Audit.RequestContext
  alias Ash.PlugHelpers

  # All V1 endpoints are now token-only (simpler!)
  # We use a negative match approach - paths that DON'T require map context
  @non_map_scoped_paths [
    ~r{^/api/v1/open_api$},
    ~r{^/api/v1/json_schema$},
    ~r{^/api/v1/health.*$}
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    case authenticate_request(conn) do
      {:ok, user, map} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        # For map-scoped endpoints, wrap user and map together as actor
        actor = if map, do: ActorWithMap.new(user, map), else: user

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))
        |> PlugHelpers.set_actor(actor)
        |> maybe_assign_map(map)

      {:ok, user} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))
        |> PlugHelpers.set_actor(user)

      {:error, reason} when is_binary(reason) ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        request_details = extract_request_details(conn)

        SecurityAudit.log_auth_event(
          :auth_failure,
          nil,
          Map.put(request_details, :failure_reason, reason)
        )

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
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        request_details = extract_request_details(conn)

        SecurityAudit.log_auth_event(
          :auth_failure,
          nil,
          Map.merge(request_details, %{
            failure_reason: internal_reason,
            external_message: external_message
          })
        )

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
    case get_session(conn, :user_id) do
      nil ->
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
    request_path = conn.request_path
    request_method = http_method_atom(conn.method)

    cond do
      request_method == :unsupported ->
        Logger.warning(
          "[CheckJsonApiAuth] Unsupported HTTP method for #{request_path}",
          path: request_path,
          method: conn.method
        )

        {:error, "Unsupported HTTP method", :unsupported_http_method}

      # All v1 map-scoped endpoints are token-only
      requires_map_context?(request_path) ->
        find_map_by_token(token)

      # Non-map-scoped endpoints (health checks, OpenAPI, etc.)
      true ->
        # For non-map-scoped endpoints, we still need to validate the token
        # but we don't need to return the map
        case find_map_by_token(token) do
          {:ok, user, _map} -> {:ok, user}
          error -> error
        end
    end
  end

  # Helper to check if path requires map context
  defp requires_map_context?(path) do
    starts_with_v1? = String.starts_with?(path, "/api/v1/")
    not_excluded? = not Enum.any?(@non_map_scoped_paths, &Regex.match?(&1, path))

    starts_with_v1? and not_excluded?
  end

  defp http_method_atom(method) do
    case method do
      "GET" -> :get
      "POST" -> :post
      "PUT" -> :put
      "PATCH" -> :patch
      "DELETE" -> :delete
      "OPTIONS" -> :options
      "HEAD" -> :head
      _ -> :unsupported
    end
  end

  defp find_map_by_token(token) do
    try do
      case WandererApp.Api.Map.get_map_by_api_key(token, load: :owner) do
        {:ok, map} when not is_nil(map) ->
          case User.by_id(map.owner.user_id, load: :characters) do
            {:ok, user} ->
              {:ok, user, map}

            {:error, error} ->
              Logger.error("[CheckJsonApiAuth] Failed to load map owner: #{inspect(error)}")

              {:error, "Authentication failed", :map_owner_not_found}
          end

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:error, "Authentication failed", :invalid_token}

        {:error, error} ->
          Logger.error("[CheckJsonApiAuth] Error querying map: #{inspect(error)}")
          {:error, "Authentication failed", :query_error}

        nil ->
          {:error, "Authentication failed", :invalid_token}
      end
    rescue
      e ->
        Logger.error("[CheckJsonApiAuth] Exception in find_map_by_token: #{inspect(e)}")
        Logger.error("[CheckJsonApiAuth] Stacktrace: #{inspect(__STACKTRACE__)}")
        {:error, "Authentication failed", :exception}
    end
  end

  defp get_user_role(user) do
    admins = WandererApp.Env.admins()
    if Enum.empty?(admins) or user.hash in admins, do: :admin, else: :user
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
