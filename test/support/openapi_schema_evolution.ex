defmodule WandererAppWeb.OpenAPISchemaEvolution do
  @moduledoc """
  Tools for detecting and tracking OpenAPI schema evolution.

  This module helps identify breaking changes in API specifications
  and generates migration guides when schemas evolve.
  """

  # alias WandererAppWeb.OpenAPISpecAnalyzer  # Currently unused

  @breaking_change_types [
    :removed_endpoint,
    :removed_operation,
    :removed_required_field,
    :removed_enum_value,
    :type_narrowing,
    :removed_response_code,
    :required_field_added,
    :parameter_location_changed
  ]

  @doc """
  Detects breaking changes between two API specifications.
  """
  def detect_breaking_changes(old_spec, new_spec) do
    %{
      endpoints: analyze_endpoint_changes(old_spec, new_spec),
      operations: analyze_operation_changes(old_spec, new_spec),
      schemas: analyze_schema_changes(old_spec, new_spec),
      parameters: analyze_parameter_changes(old_spec, new_spec),
      responses: analyze_response_changes(old_spec, new_spec)
    }
    |> identify_breaking_changes()
  end

  @doc """
  Generates a changelog between two specifications.
  """
  def generate_changelog(old_spec, new_spec, options \\ []) do
    changes = detect_all_changes(old_spec, new_spec)
    version = options[:version] || new_spec.info.version

    """
    # API Changelog - Version #{version}

    #{format_breaking_changes(changes.breaking)}

    #{format_deprecations(changes.deprecations)}

    #{format_additions(changes.additions)}

    #{format_modifications(changes.modifications)}
    """
  end

  @doc """
  Validates that a new spec is backwards compatible with an old spec.
  """
  def validate_backwards_compatibility(old_spec, new_spec) do
    breaking_changes = detect_breaking_changes(old_spec, new_spec)

    case count_breaking_changes(breaking_changes) do
      0 ->
        {:ok, "No breaking changes detected"}

      count ->
        {:error, format_validation_errors(breaking_changes, count)}
    end
  end

  @doc """
  Generates a migration guide for breaking changes.
  """
  def generate_migration_guide(old_spec, new_spec) do
    breaking_changes = detect_breaking_changes(old_spec, new_spec)

    """
    # API Migration Guide

    ## Overview
    This guide helps you migrate from API version #{old_spec.info.version} to #{new_spec.info.version}.

    ## Breaking Changes
    #{format_migration_steps(breaking_changes)}

    ## Recommended Migration Order
    #{format_migration_order(breaking_changes)}
    """
  end

  # Private functions

  defp analyze_endpoint_changes(old_spec, new_spec) do
    old_paths = Map.keys(old_spec.paths || %{})
    new_paths = Map.keys(new_spec.paths || %{})

    %{
      removed: old_paths -- new_paths,
      added: new_paths -- old_paths,
      modified: find_modified_endpoints(old_spec, new_spec)
    }
  end

  defp analyze_operation_changes(old_spec, new_spec) do
    old_ops = extract_all_operations(old_spec)
    new_ops = extract_all_operations(new_spec)

    old_op_ids = Map.keys(old_ops)
    new_op_ids = Map.keys(new_ops)

    %{
      removed: old_op_ids -- new_op_ids,
      added: new_op_ids -- old_op_ids,
      modified: find_modified_operations(old_ops, new_ops)
    }
  end

  defp analyze_schema_changes(old_spec, new_spec) do
    old_schemas = old_spec.components[:schemas] || %{}
    new_schemas = new_spec.components[:schemas] || %{}

    old_names = Map.keys(old_schemas)
    new_names = Map.keys(new_schemas)

    modified =
      Enum.reduce(old_names, [], fn name, acc ->
        case Map.get(new_schemas, name) do
          nil ->
            acc

          new_schema ->
            old_schema = Map.get(old_schemas, name)
            changes = compare_schemas(old_schema, new_schema)

            if changes != [] do
              [{name, changes} | acc]
            else
              acc
            end
        end
      end)

    %{
      removed: old_names -- new_names,
      added: new_names -- old_names,
      modified: modified
    }
  end

  defp analyze_parameter_changes(old_spec, new_spec) do
    old_ops = extract_all_operations(old_spec)
    new_ops = extract_all_operations(new_spec)

    Enum.reduce(old_ops, [], fn {op_id, old_op}, acc ->
      case Map.get(new_ops, op_id) do
        nil ->
          acc

        new_op ->
          param_changes =
            compare_parameters(
              old_op.parameters || [],
              new_op.parameters || []
            )

          if param_changes != %{} do
            [{op_id, param_changes} | acc]
          else
            acc
          end
      end
    end)
  end

  defp analyze_response_changes(old_spec, new_spec) do
    old_ops = extract_all_operations(old_spec)
    new_ops = extract_all_operations(new_spec)

    Enum.reduce(old_ops, [], fn {op_id, old_op}, acc ->
      case Map.get(new_ops, op_id) do
        nil ->
          acc

        new_op ->
          response_changes =
            compare_responses(
              old_op.responses || %{},
              new_op.responses || %{}
            )

          if response_changes != %{} do
            [{op_id, response_changes} | acc]
          else
            acc
          end
      end
    end)
  end

  defp extract_all_operations(spec) do
    Enum.reduce(spec.paths || %{}, %{}, fn {path, path_item}, acc ->
      path_item
      |> Map.from_struct()
      |> Enum.filter(fn {method, _} -> method in [:get, :post, :put, :patch, :delete] end)
      |> Enum.reduce(acc, fn {method, operation}, inner_acc ->
        op_id = operation[:operation_id] || "#{method}_#{path}"
        Map.put(inner_acc, op_id, Map.put(operation, :_path, path))
      end)
    end)
  end

  defp find_modified_endpoints(old_spec, new_spec) do
    common_paths =
      MapSet.intersection(
        MapSet.new(Map.keys(old_spec.paths || %{})),
        MapSet.new(Map.keys(new_spec.paths || %{}))
      )

    Enum.reduce(common_paths, [], fn path, acc ->
      old_item = Map.get(old_spec.paths, path)
      new_item = Map.get(new_spec.paths, path)

      if path_item_modified?(old_item, new_item) do
        [path | acc]
      else
        acc
      end
    end)
  end

  defp find_modified_operations(old_ops, new_ops) do
    common_ids =
      MapSet.intersection(
        MapSet.new(Map.keys(old_ops)),
        MapSet.new(Map.keys(new_ops))
      )

    Enum.reduce(common_ids, [], fn op_id, acc ->
      old_op = Map.get(old_ops, op_id)
      new_op = Map.get(new_ops, op_id)

      if operation_modified?(old_op, new_op) do
        [{op_id, describe_operation_changes(old_op, new_op)} | acc]
      else
        acc
      end
    end)
  end

  defp compare_schemas(old_schema, new_schema) do
    changes = []

    # Check type changes
    changes =
      if old_schema.type != new_schema.type do
        [{:type_changed, old_schema.type, new_schema.type} | changes]
      else
        changes
      end

    # Check required fields
    old_required = MapSet.new(old_schema[:required] || [])
    new_required = MapSet.new(new_schema[:required] || [])

    removed_required = MapSet.difference(old_required, new_required) |> MapSet.to_list()
    added_required = MapSet.difference(new_required, old_required) |> MapSet.to_list()

    changes2 =
      if removed_required != [] do
        [{:required_fields_removed, removed_required} | changes]
      else
        changes
      end

    changes3 =
      if added_required != [] do
        [{:required_fields_added, added_required} | changes2]
      else
        changes2
      end

    # Check properties (for object schemas)
    if old_schema.type == :object && new_schema.type == :object do
      old_props = Map.keys(old_schema[:properties] || %{})
      new_props = Map.keys(new_schema[:properties] || %{})

      removed_props = old_props -- new_props

      if removed_props != [] do
        [{:properties_removed, removed_props} | changes3]
      else
        changes3
      end
    else
      changes3
    end
  end

  defp compare_parameters(old_params, new_params) do
    old_by_name = Enum.group_by(old_params, & &1.name)
    new_by_name = Enum.group_by(new_params, & &1.name)

    removed = Map.keys(old_by_name) -- Map.keys(new_by_name)
    added = Map.keys(new_by_name) -- Map.keys(old_by_name)

    modified =
      Enum.reduce(old_by_name, [], fn {name, [old_param]}, acc ->
        case Map.get(new_by_name, name) do
          nil ->
            acc

          [new_param] ->
            if parameter_modified?(old_param, new_param) do
              [{name, describe_parameter_changes(old_param, new_param)} | acc]
            else
              acc
            end
        end
      end)

    %{
      removed: removed,
      added: added,
      modified: modified
    }
  end

  defp compare_responses(old_responses, new_responses) do
    old_codes = Map.keys(old_responses)
    new_codes = Map.keys(new_responses)

    removed = old_codes -- new_codes
    added = new_codes -- old_codes

    %{
      removed: removed,
      added: added
    }
  end

  defp path_item_modified?(old_item, new_item) do
    # Simple comparison - could be more sophisticated
    old_item != new_item
  end

  defp operation_modified?(old_op, new_op) do
    # Check various aspects that might have changed
    old_op[:deprecated] != new_op[:deprecated] ||
      old_op[:security] != new_op[:security] ||
      length(old_op[:parameters] || []) != length(new_op[:parameters] || []) ||
      Map.keys(old_op[:responses] || %{}) != Map.keys(new_op[:responses] || %{})
  end

  defp parameter_modified?(old_param, new_param) do
    old_param.required != new_param.required ||
      old_param.in != new_param.in ||
      old_param.schema != new_param.schema
  end

  defp describe_operation_changes(old_op, new_op) do
    changes = []

    changes =
      if old_op[:deprecated] != new_op[:deprecated] do
        [{:deprecated, new_op[:deprecated]} | changes]
      else
        changes
      end

    changes =
      if old_op[:security] != new_op[:security] do
        [{:security_changed, old_op[:security], new_op[:security]} | changes]
      else
        changes
      end

    changes
  end

  defp describe_parameter_changes(old_param, new_param) do
    changes = []

    changes =
      if old_param.required != new_param.required do
        [{:required_changed, old_param.required, new_param.required} | changes]
      else
        changes
      end

    changes =
      if old_param.in != new_param.in do
        [{:location_changed, old_param.in, new_param.in} | changes]
      else
        changes
      end

    changes
  end

  defp identify_breaking_changes(all_changes) do
    breaking = []

    # Removed endpoints are breaking
    breaking =
      breaking ++
        Enum.map(all_changes.endpoints.removed, fn path ->
          %{type: :removed_endpoint, path: path}
        end)

    # Removed operations are breaking
    breaking =
      breaking ++
        Enum.map(all_changes.operations.removed, fn op_id ->
          %{type: :removed_operation, operation_id: op_id}
        end)

    # Analyze schema changes for breaking changes
    breaking =
      breaking ++
        Enum.flat_map(all_changes.schemas.modified, fn {schema_name, changes} ->
          Enum.flat_map(changes, fn
            {:required_fields_added, fields} ->
              Enum.map(fields, fn field ->
                %{type: :required_field_added, schema: schema_name, field: field}
              end)

            {:properties_removed, props} ->
              Enum.map(props, fn prop ->
                %{type: :removed_field, schema: schema_name, field: prop}
              end)

            _ ->
              []
          end)
        end)

    # Parameter removals are breaking
    breaking =
      breaking ++
        Enum.flat_map(all_changes.parameters, fn {op_id, param_changes} ->
          Enum.map(param_changes.removed, fn param_name ->
            %{type: :removed_parameter, operation_id: op_id, parameter: param_name}
          end)
        end)

    # Response removals might be breaking
    breaking =
      breaking ++
        Enum.flat_map(all_changes.responses, fn {op_id, response_changes} ->
          Enum.flat_map(response_changes.removed, fn status_code ->
            # Only 2xx removals are typically breaking
            if String.starts_with?(to_string(status_code), "2") do
              [%{type: :removed_response_code, operation_id: op_id, status_code: status_code}]
            else
              []
            end
          end)
        end)

    breaking
  end

  defp detect_all_changes(old_spec, new_spec) do
    breaking_changes = detect_breaking_changes(old_spec, new_spec)

    %{
      breaking: breaking_changes,
      deprecations: detect_deprecations(old_spec, new_spec),
      additions: detect_additions(old_spec, new_spec),
      modifications: detect_modifications(old_spec, new_spec)
    }
  end

  defp detect_deprecations(_old_spec, new_spec) do
    new_ops = extract_all_operations(new_spec)

    Enum.reduce(new_ops, [], fn {op_id, op}, acc ->
      if op[:deprecated] == true do
        [%{operation_id: op_id, path: op[:_path]} | acc]
      else
        acc
      end
    end)
  end

  defp detect_additions(old_spec, new_spec) do
    %{
      endpoints: Map.keys(new_spec.paths || %{}) -- Map.keys(old_spec.paths || %{}),
      operations:
        extract_all_operations(new_spec)
        |> Map.keys()
        |> Kernel.--(extract_all_operations(old_spec) |> Map.keys()),
      schemas:
        Map.keys(new_spec.components[:schemas] || %{}) --
          Map.keys(old_spec.components[:schemas] || %{})
    }
  end

  defp detect_modifications(_old_spec, _new_spec) do
    # This would include non-breaking modifications
    []
  end

  defp count_breaking_changes(breaking_changes) when is_list(breaking_changes) do
    length(breaking_changes)
  end

  defp count_breaking_changes(breaking_changes) when is_map(breaking_changes) do
    breaking_changes
    |> Map.values()
    |> Enum.reduce(0, fn changes, acc ->
      cond do
        is_list(changes) -> acc + length(changes)
        is_map(changes) -> acc + map_size(changes)
        true -> acc
      end
    end)
  end

  defp format_breaking_changes([]), do: "## Breaking Changes\n\nNo breaking changes detected! ✅"

  defp format_breaking_changes(changes) do
    """
    ## ⚠️ Breaking Changes

    #{Enum.map_join(changes, "\n", &format_breaking_change/1)}
    """
  end

  defp format_breaking_change(%{type: :removed_endpoint, path: path}) do
    "- **Removed endpoint**: `#{path}`"
  end

  defp format_breaking_change(%{type: :removed_operation, operation_id: op_id}) do
    "- **Removed operation**: `#{op_id}`"
  end

  defp format_breaking_change(%{type: :required_field_added, schema: schema, field: field}) do
    "- **New required field**: `#{field}` added to schema `#{schema}`"
  end

  defp format_breaking_change(%{type: :removed_field, schema: schema, field: field}) do
    "- **Removed field**: `#{field}` removed from schema `#{schema}`"
  end

  defp format_breaking_change(change) do
    "- **Change**: #{inspect(change)}"
  end

  defp format_deprecations([]), do: "## Deprecations\n\nNo new deprecations."

  defp format_deprecations(deprecations) do
    """
    ## Deprecations

    #{Enum.map_join(deprecations, "\n", fn dep -> "- Operation `#{dep.operation_id}` at `#{dep.path}` is now deprecated" end)}
    """
  end

  defp format_additions(%{endpoints: [], operations: [], schemas: []}),
    do: "## Additions\n\nNo new additions."

  defp format_additions(additions) do
    """
    ## Additions

    ### New Endpoints
    #{format_list(additions.endpoints, "No new endpoints")}

    ### New Operations
    #{format_list(additions.operations, "No new operations")}

    ### New Schemas
    #{format_list(additions.schemas, "No new schemas")}
    """
  end

  defp format_modifications([]), do: "## Other Modifications\n\nNo other modifications."

  defp format_modifications(mods) do
    """
    ## Other Modifications

    #{Enum.map_join(mods, "\n", &format_modification/1)}
    """
  end

  defp format_modification(mod), do: "- #{inspect(mod)}"

  defp format_list([], empty_message), do: empty_message
  defp format_list(items, _), do: Enum.map_join(items, "\n", fn item -> "- `#{item}`" end)

  defp format_validation_errors(breaking_changes, count) do
    """
    API specification is not backwards compatible!
    Found #{count} breaking change(s):

    #{Enum.map_join(breaking_changes, "\n", &format_breaking_change/1)}

    To proceed with these breaking changes, increment the API major version.
    """
  end

  defp format_migration_steps(breaking_changes) when is_list(breaking_changes) do
    if breaking_changes == [] do
      "No breaking changes requiring migration."
    else
      Enum.map_join(breaking_changes, "\n\n", &format_migration_step/1)
    end
  end

  defp format_migration_step(%{type: :removed_endpoint, path: path}) do
    """
    ### Removed Endpoint: `#{path}`

    **Action Required**: Update your code to use alternative endpoints or remove calls to this endpoint.
    """
  end

  defp format_migration_step(%{type: :required_field_added, schema: schema, field: field}) do
    """
    ### New Required Field: `#{field}` in `#{schema}`

    **Action Required**: Update all requests that create or update `#{schema}` to include the `#{field}` field.
    """
  end

  defp format_migration_step(change) do
    """
    ### Change: #{inspect(change.type)}

    **Action Required**: Review and update affected code.

    Details: #{inspect(change)}
    """
  end

  defp format_migration_order(breaking_changes) when is_list(breaking_changes) do
    if breaking_changes == [] do
      "No specific migration order required."
    else
      """
      1. Update request payloads for new required fields
      2. Update response handling for removed fields
      3. Replace calls to removed endpoints
      4. Update parameter usage for changed parameters
      """
    end
  end
end
