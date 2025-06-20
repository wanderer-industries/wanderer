defmodule WandererAppWeb.Routers.ApiV1Router do
  @moduledoc """
  V1 API Router - AshJsonApi routes for V1 API.

  This router handles all JSON:API compliant CRUD operations for V1 resources.
  It's mounted under /api/v1/ and provides standard REST endpoints for all
  Ash resources with backward compatibility guarantees.
  """

  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    json_schema: "/json_schema",
    open_api: "/openapi"

  # V1 JSON:API routes are automatically generated from resource definitions
  # These routes follow the JSON:API specification for standard CRUD operations
end
