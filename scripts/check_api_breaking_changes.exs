#!/usr/bin/env elixir

# Check for breaking changes in OpenAPI specification
# Usage: elixir scripts/check_api_breaking_changes.exs <old_spec.json> <new_spec.json>

defmodule OpenApiDiff do
  @moduledoc """
  Compares two OpenAPI specifications and detects breaking changes.
  """

  @breaking_changes [
    # Endpoint removals
    :endpoint_removed,
    :method_removed,
    
    # Parameter changes
    :required_parameter_added,
    :parameter_removed,
    :parameter_type_changed,
    
    # Response changes
    :response_removed,
    :response_type_changed,
    :required_property_added,
    :property_removed,
    :property_type_changed,
    
    # Schema changes
    :enum_value_removed,
    :discriminator_changed
  ]

  def compare(old_spec_path, new_spec_path) do
    with {:ok, old_json} <- File.read(old_spec_path),
         {:ok, new_json} <- File.read(new_spec_path),
         {:ok, old_spec} <- decode_json(old_json),
         {:ok, new_spec} <- decode_json(new_json) do
      
      changes = detect_changes(old_spec, new_spec)
      breaking = Enum.filter(changes, &(&1.type in @breaking_changes))
      
      if Enum.empty?(breaking) do
        IO.puts("✅ No breaking changes detected")
        System.halt(0)
      else
        IO.puts("❌ Breaking changes detected:\n")
        
        breaking
        |> Enum.group_by(& &1.type)
        |> Enum.each(fn {type, changes} ->
          IO.puts("#{format_change_type(type)}:")
          Enum.each(changes, fn change ->
            IO.puts("  - #{change.path}: #{change.description}")
          end)
          IO.puts("")
        end)
        
        System.halt(1)
      end
    else
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        System.halt(2)
    end
  end

  # Try to decode JSON using available libraries
  defp decode_json(json_string) do
    cond do
      Code.ensure_loaded?(Jason) ->
        Jason.decode(json_string)
      Code.ensure_loaded?(Poison) ->
        Poison.decode(json_string)
      true ->
        # Use Erlang's json module (available in OTP 27+)
        try do
          {:ok, :json.decode(json_string, [:return_maps])}
        rescue
          _ -> {:error, "No JSON decoder available"}
        end
    end
  end

  defp detect_changes(old_spec, new_spec) do
    changes = []
    
    # Check paths
    changes = changes ++ check_paths(
      old_spec["paths"] || %{}, 
      new_spec["paths"] || %{}
    )
    
    # Check components/schemas
    changes = changes ++ check_schemas(
      get_in(old_spec, ["components", "schemas"]) || %{},
      get_in(new_spec, ["components", "schemas"]) || %{}
    )
    
    changes
  end

  defp check_paths(old_paths, new_paths) do
    changes = []
    
    # Check for removed endpoints
    changes = changes ++ Enum.flat_map(old_paths, fn {path, old_methods} ->
      case Map.get(new_paths, path) do
        nil ->
          [%{type: :endpoint_removed, path: path, description: "Endpoint removed"}]
        new_methods ->
          check_methods(path, old_methods || %{}, new_methods || %{})
      end
    end)
    
    changes
  end

  defp check_methods(path, old_methods, new_methods) do
    changes = []
    
    # Check for removed methods
    changes = changes ++ Enum.flat_map(old_methods, fn {method, old_op} ->
      case Map.get(new_methods, method) do
        nil when method in ["get", "post", "put", "patch", "delete"] ->
          [%{type: :method_removed, path: "#{path}##{method}", description: "Method removed"}]
        new_op when is_map(new_op) and is_map(old_op) ->
          check_operation(path, method, old_op, new_op)
        _ ->
          []
      end
    end)
    
    changes
  end

  defp check_operation(path, method, old_op, new_op) do
    changes = []
    operation_path = "#{path}##{method}"
    
    # Check parameters
    old_params = old_op["parameters"] || []
    new_params = new_op["parameters"] || []
    
    changes = changes ++ check_parameters(operation_path, old_params, new_params)
    
    # Check responses
    old_responses = old_op["responses"] || %{}
    new_responses = new_op["responses"] || %{}
    
    changes = changes ++ check_responses(operation_path, old_responses, new_responses)
    
    changes
  end

  defp check_parameters(path, old_params, new_params) do
    changes = []
    
    # Build parameter maps for easier comparison
    old_param_map = build_param_map(old_params)
    new_param_map = build_param_map(new_params)
    
    # Check for removed parameters
    changes = changes ++ Enum.flat_map(old_param_map, fn {{name, location}, old_param} ->
      case Map.get(new_param_map, {name, location}) do
        nil ->
          [%{type: :parameter_removed, path: path, 
             description: "Parameter '#{name}' in #{location} removed"}]
        new_param ->
          check_parameter_changes(path, name, location, old_param, new_param)
      end
    end)
    
    # Check for new required parameters
    changes = changes ++ Enum.flat_map(new_param_map, fn {{name, location}, new_param} ->
      case Map.get(old_param_map, {name, location}) do
        nil ->
          if Map.get(new_param, "required") == true do
            [%{type: :required_parameter_added, path: path,
               description: "Required parameter '#{name}' in #{location} added"}]
          else
            []
          end
        _ ->
          []
      end
    end)
    
    changes
  end

  defp build_param_map(params) do
    params
    |> Enum.map(fn param -> 
      {{param["name"], param["in"]}, param}
    end)
    |> Map.new()
  end

  defp check_parameter_changes(path, name, _location, old_param, new_param) do
    changes = []
    
    # Check type changes
    old_type = get_param_type(old_param)
    new_type = get_param_type(new_param)
    
    changes = if old_type != new_type do
      [%{type: :parameter_type_changed, path: path,
                   description: "Parameter '#{name}' type changed from #{old_type} to #{new_type}"} | changes]
    else
      changes
    end
    
    changes
  end

  defp get_param_type(param) do
    schema = param["schema"] || %{}
    schema["type"] || "unknown"
  end

  defp check_responses(path, old_responses, new_responses) do
    changes = []
    
    # Check for removed response codes
    changes = changes ++ Enum.flat_map(old_responses, fn {code, _old_resp} ->
      case Map.get(new_responses, code) do
        nil ->
          [%{type: :response_removed, path: path,
             description: "Response code #{code} removed"}]
        _new_resp ->
          # TODO: Deep check response schema changes
          []
      end
    end)
    
    changes
  end

  defp check_schemas(old_schemas, new_schemas) do
    changes = []
    
    # Check for removed schemas
    changes = changes ++ Enum.flat_map(old_schemas, fn {name, old_schema} ->
      case Map.get(new_schemas, name) do
        nil ->
          [%{type: :schema_removed, path: "#/components/schemas/#{name}",
             description: "Schema removed"}]
        new_schema ->
          check_schema_changes(name, old_schema, new_schema)
      end
    end)
    
    changes
  end

  defp check_schema_changes(name, old_schema, new_schema) do
    changes = []
    path = "#/components/schemas/#{name}"
    
    # Check required properties
    old_required = MapSet.new(old_schema["required"] || [])
    new_required = MapSet.new(new_schema["required"] || [])
    
    # New required properties are breaking
    added_required = MapSet.difference(new_required, old_required)
    changes = changes ++ Enum.map(added_required, fn prop ->
      %{type: :required_property_added, path: path,
        description: "Required property '#{prop}' added"}
    end)
    
    # Check for removed properties
    old_props = old_schema["properties"] || %{}
    new_props = new_schema["properties"] || %{}
    
    changes = changes ++ Enum.flat_map(old_props, fn {prop_name, _old_prop} ->
      case Map.get(new_props, prop_name) do
        nil ->
          [%{type: :property_removed, path: path,
             description: "Property '#{prop_name}' removed"}]
        _new_prop ->
          # TODO: Check property type changes
          []
      end
    end)
    
    # Check enum changes
    if old_schema["enum"] && new_schema["enum"] do
      old_enum = MapSet.new(old_schema["enum"])
      new_enum = MapSet.new(new_schema["enum"])
      removed_values = MapSet.difference(old_enum, new_enum)
      
      changes ++ Enum.map(removed_values, fn value ->
        %{type: :enum_value_removed, path: path,
          description: "Enum value '#{inspect(value)}' removed"}
      end)
    else
      changes
    end
  end

  defp format_change_type(type) do
    type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

# Main execution
case System.argv() do
  [old_spec, new_spec] ->
    OpenApiDiff.compare(old_spec, new_spec)
  _ ->
    IO.puts("Usage: elixir scripts/check_api_breaking_changes.exs <old_spec.json> <new_spec.json>")
    System.halt(1)
end