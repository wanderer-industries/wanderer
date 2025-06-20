defmodule WandererApp.Test.OpenApiAssert do
  @moduledoc """
  OpenAPI schema validation helpers for tests.

  Provides macros and functions to validate API responses against OpenAPI schemas.
  """

  import ExUnit.Assertions
  alias OpenApiSpex.Cast
  alias WandererAppWeb.ApiSpec

  @doc """
  Asserts that the response conforms to the OpenAPI schema.

  ## Examples

      assert_conforms!(conn, 200)
      assert_conforms!(json_response(conn, 200), "MapSchema")
  """
  defmacro assert_conforms!(conn_or_response, status_or_schema_name) do
    quote do
      WandererApp.Test.OpenApiAssert.do_assert_conforms!(
        unquote(conn_or_response),
        unquote(status_or_schema_name)
      )
    end
  end

  @doc false
  def do_assert_conforms!(%Plug.Conn{} = conn, expected_status) do
    actual_status = conn.status

    assert actual_status == expected_status,
           "Expected status #{expected_status}, got #{actual_status}"

    # Get the operation from the conn
    operation = get_operation_from_conn(conn)

    if operation do
      # Get the response schema for this status
      response_spec = get_response_spec(operation, actual_status)

      if response_spec && response_spec.content do
        # Validate JSON response
        json_resp = Jason.decode!(conn.resp_body)
        validate_response_schema(json_resp, response_spec)
      end
    end

    conn
  end

  def do_assert_conforms!(response_data, schema_name) when is_binary(schema_name) do
    schema = get_schema_by_name(schema_name)

    case Cast.cast(schema, response_data) do
      {:ok, _} ->
        response_data

      {:error, errors} ->
        flunk("Response does not conform to schema #{schema_name}:\n#{format_errors(errors)}")
    end
  end

  @doc """
  Gets the OpenAPI operation from a conn.
  """
  def get_operation_from_conn(conn) do
    # Try to get the operation from conn.private
    conn.private[:open_api_spex_operation] ||
      find_operation_by_path_and_method(conn.request_path, conn.method)
  end

  # Finds an operation by path and HTTP method.
  defp find_operation_by_path_and_method(path, method) do
    spec = ApiSpec.spec()
    method_atom = String.downcase(method) |> String.to_atom()

    # This is a simplified version - in practice you'd need proper path matching
    # that handles path parameters
    Enum.find_value(spec.paths, fn {path_pattern, path_item} ->
      if matches_path?(path, path_pattern) do
        Map.get(path_item, method_atom)
      end
    end)
  end

  # Checks if a request path matches an OpenAPI path pattern.
  defp matches_path?(request_path, pattern) do
    # Simple implementation - would need enhancement for path parameters
    request_segments = String.split(request_path, "/", trim: true)
    pattern_segments = String.split(pattern, "/", trim: true)

    length(request_segments) == length(pattern_segments) &&
      Enum.zip(request_segments, pattern_segments)
      |> Enum.all?(fn {req, pat} ->
        pat == req || String.starts_with?(pat, "{")
      end)
  end

  # Gets the response specification for a given status code.
  defp get_response_spec(operation, status) do
    status_string = to_string(status)
    operation.responses[status_string] || operation.responses["default"]
  end

  # Gets a schema by name from the API spec.
  defp get_schema_by_name(name) do
    spec = ApiSpec.spec()
    spec.components.schemas[name]
  end

  @doc """
  Validates a response against an OpenAPI operation specification.
  """
  def validate_response_against_operation(conn, operation, status) do
    # Get the response specification for this status
    response_spec = get_response_spec(operation, status)

    if response_spec && response_spec.content do
      # Decode and validate JSON response
      json_resp = Jason.decode!(conn.resp_body)
      validate_response_schema(json_resp, response_spec)
    end
  end

  # Validates response data against a response specification.
  defp validate_response_schema(data, response_spec) do
    # Get the JSON content schema
    content = response_spec.content["application/json"]

    if content && content.schema do
      case Cast.cast(content.schema, data) do
        {:ok, _} ->
          :ok

        {:error, errors} ->
          flunk("Response does not conform to OpenAPI schema:\n#{format_errors(errors)}")
      end
    end
  end

  # Formats validation errors for display.
  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(&format_error/1)
    |> Enum.join("\n")
  end

  defp format_errors(error), do: format_error(error)

  defp format_error(%{path: path, message: message}) do
    "  - #{Enum.join(path, ".")}: #{message}"
  end

  defp format_error(error) do
    "  - #{inspect(error)}"
  end

  @doc """
  Asserts that a request is valid against the OpenAPI specification.

  ## Examples

      assert_request_valid!(operation, %{
        path: %{"id" => "123"},
        query: %{"limit" => 10},
        body: %{"name" => "test"}
      })
  """
  def assert_request_valid!(operation, params) do
    case validate_request_params(operation, params) do
      :ok ->
        :ok

      {:error, errors} ->
        flunk("Request validation failed:\n#{format_errors(errors)}")
    end
  end

  @doc """
  Asserts that the API response status and content conforms to OpenAPI schema.

  This is a stricter version that fails tests if validation cannot be performed.
  """
  defmacro assert_openapi_valid!(conn, expected_status) do
    quote do
      conn = unquote(conn)
      expected_status = unquote(expected_status)

      # Verify status matches
      actual_status = conn.status

      assert actual_status == expected_status,
             "Expected status #{expected_status}, got #{actual_status}"

      # Get and validate operation
      operation = WandererApp.Test.OpenApiAssert.get_operation_from_conn(conn)

      if is_nil(operation) do
        flunk("No OpenAPI operation found for #{conn.method} #{conn.request_path}")
      end

      # Validate response schema
      WandererApp.Test.OpenApiAssert.validate_response_against_operation(
        conn,
        operation,
        actual_status
      )

      conn
    end
  end

  @doc """
  Helper to validate request parameters against OpenAPI schema.
  """
  def validate_request_params(operation, params) do
    # Validate path parameters
    path_params = Map.get(params, :path, %{})
    query_params = Map.get(params, :query, %{})
    body_params = Map.get(params, :body, nil)

    # Start with empty errors list
    errors = []

    # Validate parameters and accumulate errors
    param_errors =
      if operation.parameters do
        validate_parameters(operation.parameters, path_params, query_params)
      else
        []
      end

    # Validate request body and accumulate errors
    body_errors =
      if body_params && operation.requestBody do
        validate_request_body(operation.requestBody, body_params)
      else
        []
      end

    # Combine all errors
    all_errors = errors ++ param_errors ++ body_errors

    case all_errors do
      [] -> :ok
      _ -> {:error, all_errors}
    end
  end

  defp validate_parameters(parameters, path_params, query_params) do
    Enum.flat_map(parameters, fn param ->
      # Handle both string and atom in values for OpenApiSpex
      param_in =
        case param.in do
          in_val when in_val in [:path, "path"] -> :path
          in_val when in_val in [:query, "query"] -> :query
          _ -> :unknown
        end

      value =
        case param_in do
          :path ->
            Map.get(path_params, param.name) || Map.get(path_params, to_string(param.name))

          :query ->
            Map.get(query_params, param.name) || Map.get(query_params, to_string(param.name))

          _ ->
            nil
        end

      cond do
        param.required && is_nil(value) ->
          [{:error, "Required parameter '#{param.name}' is missing"}]

        !is_nil(value) && param.schema ->
          case Cast.cast(param.schema, value) do
            {:ok, _} -> []
            {:error, error} -> [{:error, "Parameter '#{param.name}': #{format_error(error)}"}]
          end

        true ->
          []
      end
    end)
  end

  defp validate_request_body(request_body, body_params) do
    if request_body.required && is_nil(body_params) do
      [{:error, "Required request body is missing"}]
    else
      content = request_body.content["application/json"]

      if content && content.schema && body_params do
        case Cast.cast(content.schema, body_params) do
          {:ok, _} -> []
          {:error, errors} -> [{:error, "Request body: #{format_errors(errors)}"}]
        end
      else
        []
      end
    end
  end
end
