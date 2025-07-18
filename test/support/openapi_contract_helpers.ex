defmodule WandererAppWeb.OpenAPIContractHelpers do
  @moduledoc """
  Enhanced helpers for comprehensive OpenAPI contract testing.

  Provides utilities for:
  - Response schema validation
  - Request schema validation
  - Operation lookup and validation
  - Parameter validation
  - Error response validation
  - Schema evolution tracking
  """

  import ExUnit.Assertions
  alias OpenApiSpex.{Cast, Parameter, RequestBody, Response, Schema}

  @doc """
  Validates an HTTP response against its OpenAPI schema.

  ## Examples

      assert_response_schema(conn, 200, "MapSystemResponse")
      assert_response_schema(conn, 201, "CreateMapSystemResponse", operation_id: "createMapSystem")
  """
  def assert_response_schema(conn, status_code, schema_name, opts \\ []) do
    operation_id = opts[:operation_id] || infer_operation_id(conn)
    spec = opts[:spec] || api_spec()

    with {:ok, operation} <- get_operation(spec, operation_id),
         {:ok, response_spec} <- get_response_spec(operation, status_code),
         {:ok, schema} <- get_response_schema(response_spec, schema_name, spec) do
      response_data = Jason.decode!(conn.resp_body)

      case Cast.cast(schema, response_data, spec) do
        {:ok, _} ->
          :ok

        {:error, errors} ->
          flunk("""
          Response schema validation failed for #{operation_id} (#{status_code}):

          Expected schema: #{schema_name}
          Response data: #{inspect(response_data, pretty: true)}

          Errors:
          #{format_errors(errors)}
          """)
      end
    else
      {:error, reason} -> flunk("Contract validation setup failed: #{reason}")
    end
  end

  @doc """
  Validates a request body against its OpenAPI schema.

  ## Examples

      assert_request_schema(params, "createMapSystem")
      assert_request_schema(params, "updateMapSystem", content_type: "application/json")
  """
  def assert_request_schema(params, operation_id, opts \\ []) do
    content_type = opts[:content_type] || "application/json"
    spec = opts[:spec] || api_spec()

    with {:ok, operation} <- get_operation(spec, operation_id),
         {:ok, request_body} <- get_request_body(operation),
         {:ok, schema} <- get_request_schema(request_body, content_type, spec) do
      case Cast.cast(schema, params, spec) do
        {:ok, _} ->
          :ok

        {:error, errors} ->
          flunk("""
          Request schema validation failed for #{operation_id}:

          Request data: #{inspect(params, pretty: true)}

          Errors:
          #{format_errors(errors)}
          """)
      end
    else
      {:error, reason} -> flunk("Contract validation setup failed: #{reason}")
    end
  end

  @doc """
  Validates request parameters (path, query, header) against OpenAPI spec.

  ## Examples

      assert_parameters(%{id: "123", sort: "name"}, "getMapSystems")
  """
  def assert_parameters(params, operation_id, opts \\ []) do
    spec = opts[:spec] || api_spec()

    with {:ok, operation} <- get_operation(spec, operation_id) do
      Enum.each(operation.parameters || [], fn param ->
        validate_parameter(param, params, spec)
      end)
    else
      {:error, reason} -> flunk("Parameter validation setup failed: #{reason}")
    end
  end

  @doc """
  Validates that an error response conforms to the standard error schema.
  """
  def assert_error_response(conn, expected_status) do
    assert conn.status == expected_status

    response = Jason.decode!(conn.resp_body)
    assert Map.has_key?(response, "error")
    assert is_binary(response["error"])

    # Validate against error schema if defined
    assert_response_schema(conn, expected_status, "ErrorResponse")
  end

  @doc """
  Gets all operations defined in the API spec.
  """
  def list_operations(spec \\ nil) do
    spec = spec || api_spec()

    Enum.flat_map(spec.paths, fn {path, path_item} ->
      path_item
      |> Map.from_struct()
      |> Enum.filter(fn {method, _} -> method in [:get, :post, :put, :patch, :delete] end)
      |> Enum.map(fn {method, operation} ->
        %{
          path: path,
          method: method,
          operation_id: operation.operation_id,
          summary: operation.summary,
          deprecated: operation.deprecated || false,
          parameters: length(operation.parameters || []),
          has_request_body: operation.request_body != nil,
          responses: Map.keys(operation.responses || %{})
        }
      end)
    end)
  end

  @doc """
  Validates that all operations have required documentation.
  """
  def assert_operations_documented(spec \\ nil) do
    spec = spec || api_spec()
    operations = list_operations(spec)

    Enum.each(operations, fn op ->
      assert op.operation_id != nil,
             "Operation #{op.method} #{op.path} missing operation_id"

      assert op.summary != nil,
             "Operation #{op.operation_id} missing summary"

      assert map_size(op.responses) > 0,
             "Operation #{op.operation_id} has no documented responses"
    end)
  end

  @doc """
  Gets the API specification.
  """
  def api_spec do
    WandererAppWeb.ApiSpec.spec()
  end

  # Private helpers

  defp get_operation(spec, operation_id) do
    operation =
      spec.paths
      |> Enum.flat_map(fn {_path, path_item} ->
        path_item
        |> Map.from_struct()
        |> Enum.filter(fn {method, _} -> method in [:get, :post, :put, :patch, :delete] end)
        |> Enum.map(fn {_method, op} -> op end)
      end)
      |> Enum.find(&(&1.operation_id == operation_id))

    case operation do
      nil -> {:error, "Operation '#{operation_id}' not found"}
      op -> {:ok, op}
    end
  end

  defp get_response_spec(%{responses: responses}, status_code) when is_map(responses) do
    status_key = to_string(status_code)

    case Map.get(responses, status_key) || Map.get(responses, "default") do
      nil -> {:error, "No response defined for status #{status_code}"}
      response -> {:ok, response}
    end
  end

  defp get_response_spec(_, _), do: {:error, "No responses defined"}

  defp get_response_schema(%Response{content: content}, schema_name, spec) when is_map(content) do
    # Usually we want application/json
    case Map.get(content, "application/json") do
      %{schema: schema} -> resolve_schema(schema, schema_name, spec)
      _ -> {:error, "No JSON response schema defined"}
    end
  end

  defp get_response_schema(_, _, _), do: {:error, "No response content defined"}

  defp get_request_body(%{request_body: nil}), do: {:error, "No request body defined"}
  defp get_request_body(%{request_body: body}), do: {:ok, body}
  defp get_request_body(_), do: {:error, "No request body defined"}

  defp get_request_schema(%RequestBody{content: content}, content_type, spec)
       when is_map(content) do
    case Map.get(content, content_type) do
      %{schema: schema} -> resolve_schema(schema, nil, spec)
      _ -> {:error, "No schema for content type #{content_type}"}
    end
  end

  defp get_request_schema(_, _, _), do: {:error, "No request content defined"}

  defp resolve_schema(%{"$ref": ref}, _name, spec) do
    # Handle component references like "#/components/schemas/MapSystem"
    case String.split(ref, "/") do
      ["#", "components", "schemas", schema_name] ->
        case get_schema_from_components(schema_name, spec) do
          nil -> {:error, "Schema #{schema_name} not found"}
          schema -> {:ok, schema}
        end

      _ ->
        {:error, "Invalid schema reference: #{ref}"}
    end
  end

  defp resolve_schema(schema, _name, _spec) when is_map(schema) do
    # Direct schema definition
    {:ok, struct(Schema, schema)}
  end

  defp resolve_schema(_, name, spec) when is_binary(name) do
    # Try to find by name in components
    case get_schema_from_components(name, spec) do
      nil -> {:error, "Schema #{name} not found"}
      schema -> {:ok, schema}
    end
  end

  defp get_schema_from_components(name, spec) do
    case spec.components do
      %{schemas: schemas} when is_map(schemas) ->
        Map.get(schemas, name)

      _ ->
        nil
    end
  end

  defp validate_parameter(%Parameter{} = param, values, spec) do
    param_name = param.name
    value = get_parameter_value(param, values)

    if param.required && value == nil do
      flunk("Required parameter '#{param_name}' is missing")
    end

    if value != nil && param.schema do
      case Cast.cast(param.schema, value, spec) do
        {:ok, _} ->
          :ok

        {:error, errors} ->
          flunk("""
          Parameter '#{param_name}' validation failed:
          Value: #{inspect(value)}
          Errors: #{format_errors(errors)}
          """)
      end
    end
  end

  defp get_parameter_value(%Parameter{in: :path, name: name}, values) do
    Map.get(values, String.to_atom(name)) || Map.get(values, name)
  end

  defp get_parameter_value(%Parameter{in: :query, name: name}, values) do
    Map.get(values, String.to_atom(name)) || Map.get(values, name)
  end

  defp get_parameter_value(%Parameter{in: :header, name: name}, values) do
    Map.get(values, String.to_atom(name)) || Map.get(values, name)
  end

  defp infer_operation_id(conn) do
    # Try to infer from controller action
    case conn.private do
      %{phoenix_controller: controller, phoenix_action: action} ->
        controller_name =
          controller
          |> Module.split()
          |> List.last()
          |> String.replace("Controller", "")
          |> Macro.underscore()

        "#{controller_name}_#{action}"

      _ ->
        nil
    end
  end

  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(&format_error/1)
    |> Enum.join("\n")
  end

  defp format_errors(error), do: format_error(error)

  defp format_error(%Cast.Error{} = error) do
    path = error.path |> Enum.join(".")
    "  - #{error.reason} at path: #{path}"
  end

  defp format_error(error), do: "  - #{inspect(error)}"
end
