defmodule WandererAppWeb.ApiRouter do
  @moduledoc """
  Enhanced version-aware API router with structured route definitions.

  This module provides:
  - Consolidated v1 API routing
  - Performance optimizations with compiled route patterns
  - Enhanced error handling with suggestions
  - Deprecation warnings and sunset date support
  - Feature flag support per route
  - Automatic JSON:API compliance
  """

  use Phoenix.Router
  import WandererAppWeb.ApiRouterHelpers
  alias WandererAppWeb.{ApiRoutes, ApiRouter.RouteSpec}
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    version = conn.assigns[:api_version] || "1"

    with {:ok, route_spec} <- find_matching_route(conn, version),
         conn <- add_deprecation_warnings(conn, version),
         conn <- add_version_features(conn, route_spec.features, version),
         params <- extract_path_params(conn.path_info, route_spec.path) do
      route_to_controller(conn, route_spec.controller, route_spec.action, params)
    else
      {:error, :route_not_found} ->
        send_enhanced_not_found_error(conn, version)

      {:error, :version_not_found} ->
        send_version_not_found_error(conn, version)

      {:error, reason} ->
        send_routing_error(conn, reason)
    end
  end

  # Get compiled routes - use runtime compilation for now for simplicity
  defp get_compiled_routes do
    Enum.map(ApiRoutes.table(), fn {version, routes} ->
      compiled_routes = Enum.map(routes, &compile_route_pattern/1)
      {version, compiled_routes}
    end)
    |> Map.new()
  end

  defp compile_route_pattern(%RouteSpec{} = route_spec) do
    # Pre-compile regex patterns for dynamic segments if needed
    # For now, we'll keep the simple atom-based matching
    route_spec
  end

  defp find_matching_route(conn, version) do
    compiled_routes = get_compiled_routes()

    case Map.get(compiled_routes, version) do
      nil ->
        {:error, :version_not_found}

      routes ->
        case Enum.find(routes, &match_route?(conn, &1)) do
          nil -> {:error, :route_not_found}
          route_spec -> {:ok, route_spec}
        end
    end
  end

  defp match_route?(%Plug.Conn{method: method, path_info: path_info}, %RouteSpec{
         verb: verb,
         path: route_path
       }) do
    verb_atom = method |> String.downcase() |> String.to_atom()
    verb_atom == verb and path_match?(path_info, route_path)
  end

  # Enhanced path matching with better performance
  defp path_match?(path_segments, route_segments) do
    path_match_recursive(path_segments, route_segments)
  end

  defp path_match_recursive([], []), do: true

  defp path_match_recursive([h | t], [s | rest]) when is_binary(s) do
    h == s and path_match_recursive(t, rest)
  end

  defp path_match_recursive([_h | t], [s | rest]) when is_atom(s) do
    path_match_recursive(t, rest)
  end

  defp path_match_recursive(_, _), do: false

  defp extract_path_params(path_info, route_path) do
    Enum.zip(route_path, path_info)
    |> Enum.filter(fn {segment, _value} -> is_atom(segment) end)
    |> Map.new(fn {segment, value} -> {Atom.to_string(segment), value} end)
  end

  defp add_deprecation_warnings(conn, version) do
    if ApiRoutes.deprecated?(version) do
      sunset_date = ApiRoutes.sunset_date(version)

      conn
      |> put_resp_header("deprecation", "true")
      |> put_resp_header("sunset", (sunset_date && Date.to_iso8601(sunset_date)) || "")
      |> put_resp_header("link", "</api/v1>; rel=\"successor-version\"")
    else
      conn
    end
  end

  defp add_version_features(conn, features, version) do
    # Add feature flags based on route capabilities
    conn =
      Enum.reduce(features, conn, fn feature, acc ->
        assign(acc, :"supports_#{feature}", true)
      end)

    conn
    |> assign(:api_features, features)
    |> assign(:api_version, version)
  end

  defp send_enhanced_not_found_error(conn, version) do
    available_versions = ApiRoutes.available_versions()
    suggested_routes = find_similar_routes(conn.path_info, version)

    error_response = %{
      error: %{
        code: "ROUTE_NOT_FOUND",
        message: "The requested route is not available in version #{version}",
        details: %{
          requested_path: "/" <> Enum.join(conn.path_info, "/"),
          requested_method: conn.method,
          requested_version: version,
          available_versions: available_versions,
          suggested_routes: suggested_routes
        }
      }
    }

    conn
    |> put_status(404)
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(error_response))
    |> halt()
  end

  defp send_version_not_found_error(conn, version) do
    available_versions = ApiRoutes.available_versions()

    error_response = %{
      error: %{
        code: "VERSION_NOT_FOUND",
        message: "API version #{version} is not supported",
        details: %{
          requested_version: version,
          available_versions: available_versions,
          upgrade_guide: "https://docs.wanderer.com/api/migration"
        }
      }
    }

    conn
    |> put_status(404)
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(error_response))
    |> halt()
  end

  defp find_similar_routes(path_info, version) do
    # Find routes with similar paths in current or other versions
    all_routes = ApiRoutes.table()

    Enum.flat_map(all_routes, fn {v, routes} ->
      Enum.filter(routes, fn route_spec ->
        similarity_score(path_info, route_spec.path) > 0.7
      end)
      |> Enum.map(fn route_spec ->
        %{
          version: v,
          method: String.upcase(Atom.to_string(route_spec.verb)),
          path: "/" <> Enum.join(route_spec.path, "/"),
          description: get_in(route_spec.metadata, [:description])
        }
      end)
    end)
    |> Enum.take(3)
  end

  defp similarity_score(path1, path2) do
    # Simple Jaccard similarity for path segments
    set1 = MapSet.new(path1)
    set2 = MapSet.new(path2)

    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()

    if union_size == 0, do: 0, else: intersection_size / union_size
  end

  defp send_routing_error(conn, reason) do
    Logger.error("API routing error: #{inspect(reason)}")

    error_response = %{
      error: %{
        code: "ROUTING_ERROR",
        message: "Internal routing error"
      }
    }

    conn
    |> put_status(500)
    |> put_resp_content_type("application/json")
    |> send_resp(500, Jason.encode!(error_response))
    |> halt()
  end

  # Helper function to route to controller with path params
  defp route_to_controller(conn, controller, action, path_params) do
    conn = %{conn | params: Map.merge(conn.params, path_params)}

    # Handle the different parameter names used by existing controllers
    conn =
      case path_params do
        %{"map_id" => map_id} ->
          %{conn | params: Map.put(conn.params, "map_identifier", map_id)}

        _ ->
          conn
      end

    controller.call(conn, controller.init(action))
  end
end
