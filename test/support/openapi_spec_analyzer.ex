defmodule WandererAppWeb.OpenAPISpecAnalyzer do
  @moduledoc """
  Utilities for analyzing and reporting on OpenAPI specifications.

  This module provides tools for:
  - Loading and caching API specifications
  - Analyzing spec coverage
  - Detecting schema changes
  - Generating test reports
  """

  @doc """
  Loads and caches the API specification.
  """
  def load_spec(force_reload \\ false) do
    cache_key = :wanderer_api_spec

    if force_reload do
      # Check if key exists before attempting to erase
      case :persistent_term.get(cache_key, :not_found) do
        :not_found -> :ok
        _ -> :persistent_term.erase(cache_key)
      end
    end

    case :persistent_term.get(cache_key, nil) do
      nil ->
        spec = WandererAppWeb.ApiSpec.spec()
        :persistent_term.put(cache_key, spec)
        spec

      spec ->
        spec
    end
  end

  @doc """
  Analyzes the API specification and returns comprehensive statistics.
  """
  def analyze_spec(spec \\ nil) do
    spec = spec || load_spec()

    %{
      info: analyze_info(spec),
      paths: analyze_paths(spec),
      operations: analyze_operations(spec),
      schemas: analyze_schemas(spec),
      security: analyze_security(spec),
      coverage: calculate_coverage(spec)
    }
  end

  @doc """
  Generates a markdown report of the API specification.
  """
  def generate_report(spec \\ nil) do
    spec = spec || load_spec()
    analysis = analyze_spec(spec)

    """
    # OpenAPI Specification Analysis Report

    ## API Information
    - **Title**: #{spec.info.title}
    - **Version**: #{spec.info.version}
    - **Description**: #{spec.info.description || "N/A"}

    ## Paths Summary
    - **Total Paths**: #{analysis.paths.total}
    - **Operations**: #{analysis.operations.total}
    - **Deprecated**: #{analysis.operations.deprecated}

    ## Operations by Method
    #{format_method_breakdown(analysis.operations.by_method)}

    ## Schema Coverage
    - **Total Schemas**: #{analysis.schemas.total}
    - **Request Schemas**: #{analysis.schemas.request_schemas}
    - **Response Schemas**: #{analysis.schemas.response_schemas}
    - **Shared Schemas**: #{analysis.schemas.shared_schemas}

    ## Security
    - **Security Schemes**: #{length(analysis.security.schemes)}
    - **Protected Operations**: #{analysis.security.protected_operations}
    - **Public Operations**: #{analysis.security.public_operations}

    ## Test Coverage Recommendations
    #{format_coverage_recommendations(analysis.coverage)}
    """
  end

  @doc """
  Lists all operations that need contract tests.
  """
  def operations_needing_tests(spec \\ nil) do
    spec = spec || load_spec()

    all_operations = list_all_operations(spec)

    # In a real implementation, we'd check which operations already have tests
    # For now, return all operations
    all_operations
  end

  @doc """
  Compares two API specifications to detect changes.
  """
  def compare_specs(old_spec, new_spec) do
    %{
      added_paths: find_added_paths(old_spec, new_spec),
      removed_paths: find_removed_paths(old_spec, new_spec),
      added_operations: find_added_operations(old_spec, new_spec),
      removed_operations: find_removed_operations(old_spec, new_spec),
      schema_changes: find_schema_changes(old_spec, new_spec),
      breaking_changes: detect_breaking_changes(old_spec, new_spec)
    }
  end

  # Private analysis functions

  defp analyze_info(spec) do
    %{
      title: spec.info.title,
      version: spec.info.version,
      description: spec.info.description
    }
  end

  defp analyze_paths(spec) do
    paths = Map.keys(spec.paths || %{})

    %{
      total: length(paths),
      by_prefix: group_by_prefix(paths)
    }
  end

  defp analyze_operations(spec) do
    operations = list_all_operations(spec)

    %{
      total: length(operations),
      deprecated: Enum.count(operations, & &1.deprecated),
      by_method:
        Enum.group_by(operations, & &1.method) |> Map.new(fn {k, v} -> {k, length(v)} end),
      with_request_body: Enum.count(operations, & &1.has_request_body),
      documented: Enum.count(operations, &(&1.summary != nil))
    }
  end

  defp analyze_schemas(spec) do
    schemas = spec.components[:schemas] || %{}
    schema_names = Map.keys(schemas)

    # Categorize schemas based on naming patterns
    request_schemas = Enum.filter(schema_names, &String.contains?(&1, "Request"))
    response_schemas = Enum.filter(schema_names, &String.contains?(&1, "Response"))
    shared_schemas = schema_names -- request_schemas -- response_schemas

    %{
      total: length(schema_names),
      request_schemas: length(request_schemas),
      response_schemas: length(response_schemas),
      shared_schemas: length(shared_schemas),
      by_type: categorize_schemas(schemas)
    }
  end

  defp analyze_security(spec) do
    schemes = spec.components[:security_schemes] || %{}
    operations = list_all_operations(spec)

    protected =
      Enum.count(operations, fn op ->
        op.security != nil && op.security != []
      end)

    %{
      schemes: Map.keys(schemes),
      protected_operations: protected,
      public_operations: length(operations) - protected
    }
  end

  defp calculate_coverage(spec) do
    operations = list_all_operations(spec)

    %{
      # Would need to check for examples
      operations_with_examples: 0,
      operations_with_all_responses:
        Enum.count(operations, fn op ->
          responses = Map.keys(op.responses || %{})
          # Should have at least success and error responses
          length(responses) >= 2
        end),
      # Would need to check schemas for examples
      schemas_with_examples: 0,
      total_operations: length(operations)
    }
  end

  defp list_all_operations(spec) do
    Enum.flat_map(spec.paths || %{}, fn {path, path_item} ->
      path_item
      |> Map.from_struct()
      |> Enum.filter(fn {method, _} -> method in [:get, :post, :put, :patch, :delete] end)
      |> Enum.map(fn {method, operation} ->
        %{
          path: path,
          method: method,
          operation_id: operation[:operation_id],
          summary: operation[:summary],
          deprecated: operation[:deprecated] || false,
          security: operation[:security],
          parameters: operation[:parameters] || [],
          has_request_body: Map.has_key?(operation, :request_body),
          responses: operation[:responses] || %{}
        }
      end)
    end)
  end

  defp group_by_prefix(paths) do
    paths
    |> Enum.group_by(fn path ->
      case String.split(path, "/", parts: 4) do
        ["", "api", prefix | _] -> prefix
        _ -> "other"
      end
    end)
    |> Map.new(fn {k, v} -> {k, length(v)} end)
  end

  defp categorize_schemas(schemas) do
    Enum.reduce(schemas, %{}, fn {_name, schema}, acc ->
      type = determine_schema_type(schema)
      Map.update(acc, type, 1, &(&1 + 1))
    end)
  end

  defp determine_schema_type(schema) do
    cond do
      schema.type == :object -> :object
      schema.type == :array -> :array
      schema.type == :string && schema.enum != nil -> :enum
      true -> schema.type || :unknown
    end
  end

  defp format_method_breakdown(by_method) do
    [:get, :post, :put, :patch, :delete]
    |> Enum.map(fn method ->
      count = Map.get(by_method, method, 0)
      "- **#{String.upcase(to_string(method))}**: #{count}"
    end)
    |> Enum.join("\n")
  end

  defp format_coverage_recommendations(coverage) do
    total = coverage.total_operations
    with_responses = coverage.operations_with_all_responses

    """
    - Total operations: #{total}
    - Operations with comprehensive responses: #{with_responses}
    - Coverage percentage: #{round(with_responses / total * 100)}%

    Recommendations:
    - Ensure all operations have at least success (2xx) and error (4xx) responses
    - Add examples to schemas for better documentation
    - Consider adding 5xx responses for server error scenarios
    """
  end

  # Comparison functions

  defp find_added_paths(old_spec, new_spec) do
    old_paths = MapSet.new(Map.keys(old_spec.paths || %{}))
    new_paths = MapSet.new(Map.keys(new_spec.paths || %{}))

    MapSet.difference(new_paths, old_paths) |> MapSet.to_list()
  end

  defp find_removed_paths(old_spec, new_spec) do
    old_paths = MapSet.new(Map.keys(old_spec.paths || %{}))
    new_paths = MapSet.new(Map.keys(new_spec.paths || %{}))

    MapSet.difference(old_paths, new_paths) |> MapSet.to_list()
  end

  defp find_added_operations(old_spec, new_spec) do
    old_ops = list_all_operations(old_spec) |> Enum.map(& &1.operation_id) |> MapSet.new()
    new_ops = list_all_operations(new_spec) |> Enum.map(& &1.operation_id) |> MapSet.new()

    MapSet.difference(new_ops, old_ops) |> MapSet.to_list()
  end

  defp find_removed_operations(old_spec, new_spec) do
    old_ops = list_all_operations(old_spec) |> Enum.map(& &1.operation_id) |> MapSet.new()
    new_ops = list_all_operations(new_spec) |> Enum.map(& &1.operation_id) |> MapSet.new()

    MapSet.difference(old_ops, new_ops) |> MapSet.to_list()
  end

  defp find_schema_changes(old_spec, new_spec) do
    old_schemas = old_spec.components[:schemas] || %{}
    new_schemas = new_spec.components[:schemas] || %{}

    %{
      added:
        MapSet.difference(MapSet.new(Map.keys(new_schemas)), MapSet.new(Map.keys(old_schemas)))
        |> MapSet.to_list(),
      removed:
        MapSet.difference(MapSet.new(Map.keys(old_schemas)), MapSet.new(Map.keys(new_schemas)))
        |> MapSet.to_list(),
      modified: find_modified_schemas(old_schemas, new_schemas)
    }
  end

  defp find_modified_schemas(old_schemas, new_schemas) do
    Enum.reduce(old_schemas, [], fn {name, old_schema}, acc ->
      case Map.get(new_schemas, name) do
        nil ->
          acc

        new_schema ->
          if schemas_differ?(old_schema, new_schema) do
            [name | acc]
          else
            acc
          end
      end
    end)
  end

  defp schemas_differ?(old_schema, new_schema) do
    deep_schema_comparison(old_schema, new_schema)
  end

  # Comprehensive schema comparison that checks for semantic differences
  defp deep_schema_comparison(old_schema, new_schema) when old_schema == new_schema, do: false

  defp deep_schema_comparison(old_schema, new_schema)
       when is_map(old_schema) and is_map(new_schema) do
    old_keys = Map.keys(old_schema) |> MapSet.new()
    new_keys = Map.keys(new_schema) |> MapSet.new()

    # Check for added/removed keys
    keys_differ = not MapSet.equal?(old_keys, new_keys)

    # Check for value differences in common keys
    common_keys = MapSet.intersection(old_keys, new_keys)

    values_differ =
      Enum.any?(common_keys, fn key ->
        deep_schema_comparison(Map.get(old_schema, key), Map.get(new_schema, key))
      end)

    keys_differ or values_differ
  end

  defp deep_schema_comparison(old_schema, new_schema)
       when is_list(old_schema) and is_list(new_schema) do
    length(old_schema) != length(new_schema) or
      Enum.zip(old_schema, new_schema)
      |> Enum.any?(fn {old_item, new_item} -> deep_schema_comparison(old_item, new_item) end)
  end

  defp deep_schema_comparison(_old_schema, _new_schema), do: true

  defp detect_breaking_changes(old_spec, new_spec) do
    %{
      removed_paths: find_removed_paths(old_spec, new_spec),
      removed_operations: find_removed_operations(old_spec, new_spec),
      # Would need to implement
      removed_required_params: [],
      # Would need to implement
      removed_schema_fields: [],
      # Would need to implement
      narrowed_types: []
    }
  end
end
