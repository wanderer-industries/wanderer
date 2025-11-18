defmodule WandererAppWeb.ApiSpecV1 do
  @moduledoc """
  OpenAPI spec that combines legacy and v1 JSON:API endpoints.
  """

  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{OpenApi, Info, Components}

  @impl OpenApiSpex.OpenApi
  def spec do
    # Get the base spec from the original
    base_spec = WandererAppWeb.ApiSpec.spec()

    # Get v1 spec
    v1_spec = WandererAppWeb.OpenApiV1Spec.spec()

    # Tag legacy paths and v1 paths appropriately
    tagged_legacy_paths = tag_paths(base_spec.paths || %{}, "Legacy API")
    # v1 paths already have tags from AshJsonApi, keep them as-is
    v1_paths = v1_spec.paths || %{}

    # Merge the specs
    merged_paths = Map.merge(tagged_legacy_paths, v1_paths)

    # Merge components
    merged_components = %Components{
      securitySchemes:
        Map.merge(
          get_security_schemes(base_spec),
          get_security_schemes(v1_spec)
        ),
      schemas:
        Map.merge(
          get_schemas(base_spec),
          get_schemas(v1_spec)
        ),
      responses:
        Map.merge(
          get_responses(base_spec),
          get_responses(v1_spec)
        )
    }

    %OpenApi{
      info: %Info{
        title: "WandererApp API (Legacy & v1)",
        version: "1.1.0",
        description: """
        Complete API documentation for WandererApp including both legacy endpoints and v1 JSON:API endpoints.

        ## Authentication

        All endpoints require authentication via Bearer token:
        ```
        Authorization: Bearer YOUR_API_KEY
        ```

        ## API Versions

        - **Legacy API** (`/api/*`): Original endpoints, maintained for backward compatibility
        - **v1 JSON:API** (`/api/v1/*`): New standardized JSON:API endpoints with filtering, sorting, and pagination
        """
      },
      servers: base_spec.servers,
      paths: merged_paths,
      components: merged_components,
      tags: merge_tags(base_spec, v1_spec),
      security: [%{"bearerAuth" => []}]
    }
  end

  defp get_security_schemes(%{components: %{securitySchemes: schemes}}) when is_map(schemes),
    do: schemes

  defp get_security_schemes(_), do: %{}

  defp get_schemas(%{components: %{schemas: schemas}}) when is_map(schemas), do: schemas
  defp get_schemas(_), do: %{}

  defp get_responses(%{components: %{responses: responses}}) when is_map(responses), do: responses
  defp get_responses(_), do: %{}

  defp merge_tags(_base_spec, v1_spec) do
    base_tags = [
      %{name: "Legacy API", description: "Original API endpoints"}
    ]

    # Get tags from v1 spec if available
    spec_tags = Map.get(v1_spec, :tags, [])

    base_tags ++ spec_tags
  end

  # Tag all operations in paths with the given tag
  defp tag_paths(paths, tag) when is_map(paths) do
    Map.new(paths, fn {path, path_item} ->
      {path, tag_path_item(path_item, tag)}
    end)
  end

  # Handle OpenApiSpex.PathItem structs
  defp tag_path_item(%OpenApiSpex.PathItem{} = path_item, tag) do
    path_item
    |> maybe_tag_operation(:get, tag)
    |> maybe_tag_operation(:put, tag)
    |> maybe_tag_operation(:post, tag)
    |> maybe_tag_operation(:delete, tag)
    |> maybe_tag_operation(:patch, tag)
    |> maybe_tag_operation(:options, tag)
    |> maybe_tag_operation(:head, tag)
  end

  # Handle plain maps (from AshJsonApi)
  defp tag_path_item(path_item, tag) when is_map(path_item) do
    Map.new(path_item, fn {method, operation} ->
      {method, add_tag_to_operation(operation, tag)}
    end)
  end

  defp tag_path_item(path_item, _tag), do: path_item

  defp maybe_tag_operation(path_item, method, tag) do
    case Map.get(path_item, method) do
      nil -> path_item
      operation -> Map.put(path_item, method, add_tag_to_operation(operation, tag))
    end
  end

  defp add_tag_to_operation(%OpenApiSpex.Operation{} = operation, tag) do
    %{operation | tags: [tag | List.wrap(operation.tags)]}
  end

  defp add_tag_to_operation(%{} = operation, tag) do
    Map.update(operation, :tags, [tag], fn existing_tags ->
      [tag | List.wrap(existing_tags)]
    end)
  end

  defp add_tag_to_operation(operation, _tag), do: operation
end
