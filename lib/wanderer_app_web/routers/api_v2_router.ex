defmodule WandererAppWeb.Routers.ApiV2Router do
  @moduledoc """
  V2 API Router - AshJsonApi routes for V2 API.

  This router will handle JSON:API compliant operations for V2 resources.
  Currently configured but not yet populated with resources.
  It's prepared for mounting under /api/v2/ when V2 resources are ready.
  """

  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    json_schema: "/json_schema",
    open_api: "/openapi"

  # V2 JSON:API routes will be generated as V2 resources are added
end
