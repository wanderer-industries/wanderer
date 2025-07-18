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

    # Merge the specs
    merged_paths = Map.merge(base_spec.paths || %{}, v1_spec.paths || %{})

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

    # Add custom v1 tags
    v1_label_tags = [
      %{name: "v1 JSON:API", description: "JSON:API compliant endpoints with advanced querying"}
    ]

    base_tags ++ v1_label_tags ++ spec_tags
  end
end
