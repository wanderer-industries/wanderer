defmodule WandererAppWeb.ApiRouter.Introspection do
  @moduledoc """
  Route introspection and documentation generation for the API.

  This module provides utilities for analyzing routes, generating
  documentation, and creating OpenAPI specifications.
  """

  alias WandererAppWeb.{ApiRoutes, ApiRouter.RouteSpec}

  @doc """
  List all routes for a specific version or all versions.
  """
  def list_routes(version \\ nil) do
    case version do
      nil -> ApiRoutes.table()
      v -> %{v => ApiRoutes.routes_for_version(v)}
    end
  end

  @doc """
  Find route information by version, method, and path.
  """
  def route_info(version, method, path) do
    routes = ApiRoutes.routes_for_version(version)
    method_atom = method |> String.downcase() |> String.to_atom()
    normalized_path = normalize_path(path)

    Enum.find(routes, fn route_spec ->
      route_spec.verb == method_atom and
        path_matches?(normalized_path, route_spec.path)
    end)
  end

  @doc """
  Get all routes that match a specific controller.
  """
  def routes_for_controller(controller, version \\ nil) do
    routes =
      case version do
        nil ->
          ApiRoutes.table()
          |> Enum.flat_map(fn {_v, routes} -> routes end)

        v ->
          ApiRoutes.routes_for_version(v)
      end

    Enum.filter(routes, fn route_spec ->
      route_spec.controller == controller
    end)
  end

  @doc """
  Get all routes that support a specific feature.
  """
  def routes_with_feature(feature, version \\ nil) do
    routes =
      case version do
        nil ->
          ApiRoutes.table()
          |> Enum.flat_map(fn {_v, routes} -> routes end)

        v ->
          ApiRoutes.routes_for_version(v)
      end

    Enum.filter(routes, fn route_spec ->
      feature in route_spec.features
    end)
  end

  @doc """
  Generate OpenAPI 3.0 specification for a version.
  """
  def generate_openapi_spec(version) do
    routes = ApiRoutes.routes_for_version(version)

    %{
      openapi: "3.0.0",
      info: %{
        title: "Wanderer API",
        version: version,
        description: "EVE Online mapping tool API",
        contact: %{
          name: "Wanderer Support",
          url: "https://docs.wanderer.com"
        }
      },
      servers: [
        %{
          url: "/api/v#{version}",
          description: "API v#{version} endpoint"
        }
      ],
      paths: generate_paths(routes),
      components: %{
        securitySchemes: %{
          bearerAuth: %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        }
      }
    }
  end

  @doc """
  Generate a simple route summary for documentation.
  """
  def generate_route_summary(version \\ "1") do
    routes = ApiRoutes.routes_for_version(version)

    Enum.group_by(routes, fn route_spec ->
      # Group by controller for better organization
      route_spec.controller
      |> Module.split()
      |> List.last()
      |> String.replace("Controller", "")
    end)
    |> Enum.map(fn {controller_name, controller_routes} ->
      %{
        controller: controller_name,
        routes: Enum.map(controller_routes, &route_to_summary/1)
      }
    end)
  end

  @doc """
  Validate route definitions and return any issues.
  """
  def validate_routes(version \\ nil) do
    routes =
      case version do
        nil ->
          ApiRoutes.table()
          |> Enum.flat_map(fn {v, routes} ->
            Enum.map(routes, fn route -> {v, route} end)
          end)

        v ->
          ApiRoutes.routes_for_version(v)
          |> Enum.map(fn route -> {v, route} end)
      end

    Enum.reduce(routes, [], fn {v, route_spec}, errors ->
      case RouteSpec.validate(route_spec) do
        {:ok, _} -> errors
        {:error, error} -> [{v, route_spec, error} | errors]
      end
    end)
  end

  @doc """
  Find duplicate routes (same method and path).
  """
  def find_duplicate_routes(version \\ nil) do
    routes =
      case version do
        nil ->
          ApiRoutes.table()
          |> Enum.flat_map(fn {v, routes} ->
            Enum.map(routes, fn route -> {v, route} end)
          end)

        v ->
          ApiRoutes.routes_for_version(v)
          |> Enum.map(fn route -> {v, route} end)
      end

    routes
    |> Enum.group_by(fn {_v, route_spec} ->
      {route_spec.verb, normalize_path_for_comparison(route_spec.path)}
    end)
    |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
    |> Enum.map(fn {key, duplicates} ->
      %{
        route_signature: key,
        duplicates: duplicates
      }
    end)
  end

  # Private helper functions

  defp normalize_path(path) when is_list(path), do: path

  defp normalize_path(path) when is_binary(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_path_for_comparison(path) do
    # Replace parameter atoms with a standard placeholder for comparison
    Enum.map(path, fn
      segment when is_atom(segment) -> ":param"
      segment -> segment
    end)
  end

  defp path_matches?(request_path, route_path) when length(request_path) != length(route_path) do
    false
  end

  defp path_matches?([], []), do: true

  defp path_matches?([req_segment | req_rest], [route_segment | route_rest])
       when is_binary(route_segment) do
    req_segment == route_segment and path_matches?(req_rest, route_rest)
  end

  defp path_matches?([_req_segment | req_rest], [route_segment | route_rest])
       when is_atom(route_segment) do
    # Route segment is a parameter (atom), so it matches any request segment
    path_matches?(req_rest, route_rest)
  end

  defp path_matches?(_, _), do: false

  defp generate_paths(routes) do
    routes
    |> Enum.group_by(&openapi_path_key/1)
    |> Enum.reduce(%{}, fn {path_key, path_routes}, acc ->
      operations =
        Enum.reduce(path_routes, %{}, fn route_spec, ops ->
          method_key = Atom.to_string(route_spec.verb)
          operation = generate_operation(route_spec)
          Map.put(ops, method_key, operation)
        end)

      Map.put(acc, path_key, operations)
    end)
  end

  defp openapi_path_key(route_spec) do
    "/" <>
      Enum.join(
        Enum.map(route_spec.path, fn
          segment when is_atom(segment) -> "{#{segment}}"
          segment -> segment
        end),
        "/"
      )
  end

  defp generate_operation(route_spec) do
    metadata = route_spec.metadata

    %{
      summary: Map.get(metadata, :description, ""),
      operationId: "#{route_spec.controller}_#{route_spec.action}",
      tags: [extract_tag_from_controller(route_spec.controller)],
      parameters: generate_parameters(route_spec),
      responses: generate_responses(route_spec),
      security: if(Map.get(metadata, :auth_required, false), do: [%{bearerAuth: []}], else: [])
    }
  end

  defp extract_tag_from_controller(controller) do
    controller
    |> Module.split()
    |> List.last()
    |> String.replace(~r/(API)?Controller$/, "")
  end

  defp generate_parameters(route_spec) do
    # Extract path parameters
    path_params =
      route_spec.path
      |> Enum.filter(&is_atom/1)
      |> Enum.map(fn param ->
        %{
          name: Atom.to_string(param),
          in: "path",
          required: true,
          schema: %{type: "string"}
        }
      end)

    # Add query parameters based on features
    query_params =
      route_spec.features
      |> Enum.flat_map(&feature_to_parameters/1)

    path_params ++ query_params
  end

  defp feature_to_parameters("filtering") do
    [
      %{
        name: "filter",
        in: "query",
        required: false,
        schema: %{type: "object"},
        description: "Filter parameters"
      }
    ]
  end

  defp feature_to_parameters("sorting") do
    [
      %{
        name: "sort",
        in: "query",
        required: false,
        schema: %{type: "string"},
        description: "Sort fields (comma-separated)"
      }
    ]
  end

  defp feature_to_parameters("pagination") do
    [
      %{
        name: "page[number]",
        in: "query",
        required: false,
        schema: %{type: "integer", minimum: 1},
        description: "Page number"
      },
      %{
        name: "page[size]",
        in: "query",
        required: false,
        schema: %{type: "integer", minimum: 1, maximum: 100},
        description: "Page size"
      }
    ]
  end

  defp feature_to_parameters("includes") do
    [
      %{
        name: "include",
        in: "query",
        required: false,
        schema: %{type: "string"},
        description: "Related resources to include (comma-separated)"
      }
    ]
  end

  defp feature_to_parameters("sparse_fieldsets") do
    [
      %{
        name: "fields",
        in: "query",
        required: false,
        schema: %{type: "object"},
        description: "Sparse fieldsets"
      }
    ]
  end

  defp feature_to_parameters(_), do: []

  defp generate_responses(route_spec) do
    metadata = route_spec.metadata
    success_status = Map.get(metadata, :success_status, 200)
    content_type = Map.get(metadata, :content_type, "application/vnd.api+json")

    responses = %{
      to_string(success_status) => %{
        description: "Success",
        content: %{
          content_type => %{
            schema: %{type: "object"}
          }
        }
      }
    }

    # Add error responses
    if Map.get(metadata, :auth_required, false) do
      Map.put(responses, "401", %{
        description: "Unauthorized",
        content: %{
          "application/json" => %{
            schema: %{type: "object"}
          }
        }
      })
    else
      responses
    end
  end

  defp route_to_summary(route_spec) do
    %{
      method: String.upcase(Atom.to_string(route_spec.verb)),
      path: "/" <> Enum.join(route_spec.path, "/"),
      action: route_spec.action,
      features: route_spec.features,
      auth_required: get_in(route_spec.metadata, [:auth_required]),
      description: get_in(route_spec.metadata, [:description])
    }
  end
end
