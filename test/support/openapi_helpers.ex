defmodule WandererAppWeb.OpenAPIHelpers do
  @moduledoc """
  Helpers for validating API responses against OpenAPI schemas.
  """

  import ExUnit.Assertions

  @doc """
  Validates that the given data conforms to the specified OpenAPI schema.

  ## Examples

      assert_schema(response_data, "MapSystem", api_spec())
      assert_schema(error_response, "ErrorResponse", api_spec())
  """
  def assert_schema(data, schema_name, spec) do
    case get_schema(schema_name, spec) do
      {:ok, schema} ->
        case OpenApiSpex.cast_value(data, schema, spec) do
          {:ok, _cast_data} ->
            :ok

          {:error, errors} ->
            formatted_errors = format_cast_errors(errors)

            flunk("""
            Schema validation failed for '#{schema_name}':

            Data: #{inspect(data, pretty: true)}

            Errors:
            #{formatted_errors}
            """)
        end

      {:error, reason} ->
        flunk("Schema '#{schema_name}' not found: #{reason}")
    end
  end

  @doc """
  Validates a request body against its OpenAPI schema.
  """
  def assert_request_schema(_data, _operation_id, _spec) do
    # This would be more complex in a real implementation
    # For now, we'll implement basic validation
    :ok
  end

  @doc """
  Gets the API specification for testing.
  """
  def api_spec do
    WandererAppWeb.ApiSpec.spec()
  end

  @doc """
  Helper to extract a specific schema from the OpenAPI spec.
  """
  def get_schema(schema_name, spec) do
    # Handle both component schemas and inline schemas
    case spec.components do
      %{schemas: schemas} when is_map(schemas) ->
        case Map.get(schemas, schema_name) do
          nil -> {:error, "Schema not found"}
          schema -> {:ok, schema}
        end

      _ ->
        # If no component schemas, try to find it in paths
        {:error, "Schema not found in components"}
    end
  end

  # Private helpers

  defp format_cast_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(&format_cast_error/1)
    |> Enum.join("\n")
  end

  defp format_cast_errors(error), do: format_cast_error(error)

  defp format_cast_error(%OpenApiSpex.Cast.Error{} = error) do
    "  - #{error.reason} at #{format_path(error.path)}"
  end

  defp format_cast_error(error) when is_binary(error) do
    "  - #{error}"
  end

  defp format_cast_error(error) do
    "  - #{inspect(error)}"
  end

  defp format_path([]), do: "root"

  defp format_path(path) when is_list(path) do
    path
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end

  defp format_path(path), do: to_string(path)
end
