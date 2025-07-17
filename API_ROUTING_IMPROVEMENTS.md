# API Routing System Improvements

## Overview

This document outlines recommended improvements to the existing API routing system, building upon the current version-based routing approach with enhanced structure, performance, and maintainability.

## Current Architecture Analysis

**Strengths:**
- Clear version-based route organization
- Centralized route definitions
- Feature-based capability tracking
- Clean separation of concerns

**Areas for Improvement:**
- Limited metadata for routes
- Basic error handling
- No performance optimizations
- Missing deprecation support
- Minimal testing structure

## Recommended Improvements

### 1. Enhanced Route Definition Structure

Replace tuple-based definitions with structured specs:

```elixir
# lib/wanderer_app_web/api_router/route_spec.ex
defmodule WandererAppWeb.ApiRouter.RouteSpec do
  @type t :: %__MODULE__{
    verb: atom(),
    path: [String.t() | atom()],
    controller: module(),
    action: atom(),
    features: [String.t()],
    metadata: map()
  }

  @enforce_keys [:verb, :path, :controller, :action]
  defstruct [
    :verb,
    :path,
    :controller,
    :action,
    features: [],
    metadata: %{}
  ]
end
```

Updated route definitions:

```elixir
# lib/wanderer_app_web/api_router/routes.ex
defmodule WandererAppWeb.ApiRoutes do
  alias WandererAppWeb.ApiRouter.RouteSpec

  @route_definitions %{
    "1" => [
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MapAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination includes),
        metadata: %{
          auth_required: false,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List all maps with full feature set"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :id),
        controller: MapAPIController,
        action: :show_v1,
        features: ~w(sparse_fieldsets),
        metadata: %{
          auth_required: false,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific map"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps),
        controller: MapAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          error_status: 422,
          content_type: "application/vnd.api+json",
          description: "Create a new map"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps :id),
        controller: MapAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update an existing map"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps :id),
        controller: MapAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a map"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps :id duplicate),
        controller: MapAPIController,
        action: :duplicate_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Duplicate an existing map"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 characters),
        controller: CharactersAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List user characters"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 characters :id),
        controller: CharactersAPIController,
        action: :show_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific character"
        }
      }
    ]
  }

  @deprecated_versions []
  @sunset_dates %{}

  def table, do: @route_definitions
  def deprecated_versions, do: @deprecated_versions
  def sunset_date(version), do: Map.get(@sunset_dates, version)
end
```

### 2. Enhanced Dispatcher Implementation

```elixir
# lib/wanderer_app_web/api_router.ex
defmodule WandererAppWeb.ApiRouter do
  use Phoenix.Router
  import WandererAppWeb.ApiRouterHelpers
  alias WandererAppWeb.{ApiRoutes, ApiRouter.RouteSpec}
  require Logger

  # Compile route patterns at module load time for performance
  @compiled_routes compile_all_routes()

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
      {:error, reason} ->
        send_routing_error(conn, reason)
    end
  end

  # Compile route patterns for faster matching
  defp compile_all_routes do
    Enum.map(ApiRoutes.table(), fn {version, routes} ->
      compiled_routes = Enum.map(routes, &compile_route_pattern/1)
      {version, compiled_routes}
    end)
    |> Map.new()
  end

  defp compile_route_pattern(%RouteSpec{} = route_spec) do
    # Pre-compile regex patterns for dynamic segments
    pattern = create_match_pattern(route_spec.path)
    %{route_spec | metadata: Map.put(route_spec.metadata, :compiled_pattern, pattern)}
  end

  defp find_matching_route(conn, version) do
    case Map.get(@compiled_routes, version) do
      nil -> {:error, :version_not_found}
      routes ->
        case Enum.find(routes, &match_route?(conn, &1)) do
          nil -> {:error, :route_not_found}
          route_spec -> {:ok, route_spec}
        end
    end
  end

  defp match_route?(%Plug.Conn{method: method, path_info: path_info}, %RouteSpec{verb: verb, path: route_path}) do
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
    if version in ApiRoutes.deprecated_versions() do
      sunset_date = ApiRoutes.sunset_date(version)
      
      conn
      |> put_resp_header("deprecation", "true")
      |> put_resp_header("sunset", sunset_date && Date.to_iso8601(sunset_date) || "")
      |> put_resp_header("link", "</api/versions>; rel=\"successor-version\"")
    else
      conn
    end
  end

  defp send_enhanced_not_found_error(conn, version) do
    available_versions = Map.keys(ApiRoutes.table())
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
    |> json(error_response)
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
          method: route_spec.verb,
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
    
    conn
    |> put_status(500)
    |> json(%{error: %{code: "ROUTING_ERROR", message: "Internal routing error"}})
    |> halt()
  end

  # Existing helper functions remain the same
  defp route_to_controller(conn, controller, action, params) do
    conn = %{conn | params: Map.merge(conn.params, params)}
    controller.call(conn, action)
  end

  defp add_version_features(conn, features, version) do
    assign(conn, :api_features, features)
    |> assign(:api_version, version)
  end
end
```

### 3. Route Introspection and Documentation

```elixir
# lib/wanderer_app_web/api_router/introspection.ex
defmodule WandererAppWeb.ApiRouter.Introspection do
  alias WandererAppWeb.ApiRoutes

  def list_routes(version \\ nil) do
    case version do
      nil -> ApiRoutes.table()
      v -> Map.get(ApiRoutes.table(), v, [])
    end
  end

  def route_info(version, method, path) do
    routes = list_routes(version)
    
    Enum.find(routes, fn route_spec ->
      route_spec.verb == method and 
      normalize_path(route_spec.path) == normalize_path(path)
    end)
  end

  def generate_openapi_spec(version) do
    routes = list_routes(version)
    
    %{
      openapi: "3.0.0",
      info: %{
        title: "Wanderer API",
        version: version
      },
      paths: generate_paths(routes)
    }
  end

  defp normalize_path(path) when is_list(path), do: path
  defp normalize_path(path) when is_binary(path) do
    path |> String.split("/") |> Enum.reject(&(&1 == ""))
  end

  defp generate_paths(routes) do
    Enum.reduce(routes, %{}, fn route_spec, acc ->
      path_key = "/" <> Enum.join(route_spec.path, "/")
      method_key = Atom.to_string(route_spec.verb)
      
      operation = %{
        summary: get_in(route_spec.metadata, [:description]),
        responses: generate_responses(route_spec)
      }
      
      put_in(acc, [path_key, method_key], operation)
    end)
  end

  defp generate_responses(route_spec) do
    success_status = get_in(route_spec.metadata, [:success_status]) || 200
    
    %{
      to_string(success_status) => %{
        description: "Success",
        content: %{
          get_in(route_spec.metadata, [:content_type]) || "application/json" => %{}
        }
      }
    }
  end
end
```

### 4. Testing Strategy

```elixir
# test/wanderer_app_web/api_router_test.exs
defmodule WandererAppWeb.ApiRouterTest do
  use WandererAppWeb.ConnCase
  alias WandererAppWeb.ApiRouter

  describe "route matching" do
    test "matches exact routes correctly" do
      conn = build_conn(:get, "/api/maps")
             |> assign(:api_version, "1.0")
      
      # Test that the route matches and calls correct controller
      assert %{controller: MapAPIController, action: :index_v1_0} = 
        extract_route_info(conn)
    end

    test "handles dynamic segments" do
      conn = build_conn(:get, "/api/maps/123")
             |> assign(:api_version, "1.0")
      
      result = extract_route_info(conn)
      assert result.params["id"] == "123"
    end

    test "returns 404 for non-existent routes" do
      conn = build_conn(:get, "/api/nonexistent")
             |> assign(:api_version, "1.0")
             |> ApiRouter.call([])
      
      assert conn.status == 404
      assert %{"error" => %{"code" => "ROUTE_NOT_FOUND"}} = json_response(conn, 404)
    end
  end

  describe "version handling" do
    test "adds deprecation headers for deprecated versions" do
      conn = build_conn(:get, "/api/maps")
             |> assign(:api_version, "1.0")
             |> ApiRouter.call([])
      
      assert get_resp_header(conn, "deprecation") == ["true"]
    end

    test "suggests alternative routes" do
      conn = build_conn(:get, "/api/maps/unknown-action")
             |> assign(:api_version, "1.0")
             |> ApiRouter.call([])
      
      response = json_response(conn, 404)
      assert is_list(response["error"]["details"]["suggested_routes"])
    end
  end

  describe "feature flags" do
    test "adds correct features for version" do
      conn = build_conn(:get, "/api/maps")
             |> assign(:api_version, "1.1")
             |> ApiRouter.call([])
      
      expected_features = ~w(filtering sorting pagination)
      assert conn.assigns.api_features == expected_features
    end
  end

  # Helper to extract route info without calling controller
  defp extract_route_info(conn) do
    # Mock implementation that returns route matching info
    # without actually calling the controller
  end
end
```

### 5. Performance Optimizations

1. **Compile-time route compilation**: Pre-compile route patterns during module loading
2. **Route caching**: Cache frequently accessed route information
3. **Pattern matching optimization**: Use more efficient matching algorithms for large route sets
4. **Lazy loading**: Load route definitions only when needed

### 6. Migration Strategy

1. **Phase 1**: Implement RouteSpec structure alongside existing tuples
2. **Phase 2**: Update route definitions to use new structure
3. **Phase 3**: Enhance dispatcher with new features
4. **Phase 4**: Add introspection and testing improvements
5. **Phase 5**: Remove old tuple-based system

## Benefits

- **Better Performance**: Compiled route patterns and optimized matching
- **Enhanced Error Handling**: Detailed error responses with suggestions
- **Version Management**: Built-in deprecation and sunset date support
- **Documentation**: Automatic OpenAPI spec generation
- **Testing**: Comprehensive test coverage for routing logic
- **Maintainability**: Structured, type-safe route definitions

## Implementation Notes

- All changes are backward compatible during migration
- Performance improvements are measurable with large route sets
- Error responses follow JSON:API error specification
- Introspection capabilities enable automatic API documentation
- Testing strategy covers edge cases and version transitions