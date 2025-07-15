defmodule WandererAppWeb.OpenApi do
  @moduledoc """
  Generates OpenAPI spec for v1 JSON:API endpoints using AshJsonApi.
  """
  
  alias OpenApiSpex.{OpenApi, Info, Server, Components}
  
  def spec do
    %OpenApi{
      info: %Info{
        title: "WandererApp v1 JSON:API",
        version: "1.0.0",
        description: """
        JSON:API compliant endpoints for WandererApp.
        
        ## Features
        - Filtering: Use `filter[attribute]=value` parameters
        - Sorting: Use `sort=attribute` or `sort=-attribute` for descending
        - Pagination: Use `page[limit]=n` and `page[offset]=n`
        - Relationships: Include related resources with `include=relationship`
        
        ## Authentication
        All endpoints require Bearer token authentication:
        ```
        Authorization: Bearer YOUR_API_KEY
        ```
        """
      },
      servers: [
        Server.from_endpoint(WandererAppWeb.Endpoint)
      ],
      paths: AshJsonApi.OpenApi.paths([WandererApp.Api], [WandererApp.Api], %{}),
      tags: AshJsonApi.OpenApi.tags([WandererApp.Api]),
      components: %Components{
        responses: AshJsonApi.OpenApi.responses(),
        schemas: AshJsonApi.OpenApi.schemas([WandererApp.Api]),
        securitySchemes: %{
          "bearerAuth" => %{
            "type" => "http",
            "scheme" => "bearer",
            "description" => "Map API key for authentication"
          }
        }
      },
      security: [%{"bearerAuth" => []}]
    }
  end
end