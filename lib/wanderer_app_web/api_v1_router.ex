defmodule WandererAppWeb.ApiV1Router do
  require Logger

  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    prefix: "/api/v1",
    open_api: "/open_api",
    json_schema: "/json_schema",
    open_api_title: "WandererApp v1 JSON:API",
    open_api_version: "1.0.0",
    modify_open_api: {WandererAppWeb.OpenApi, :spec, []},
    modify_conn: {__MODULE__, :add_context, []}

  @doc """
  Adds Ash context to the connection.

  This function is called by AshJsonApi for each request to inject context
  into the Ash action. The context includes:
  - `actor`: The authenticated user (already set via Ash.PlugHelpers.set_actor/2)
  - `map`: The authenticated map (passed via conn.assigns.map)

  The map context is used by InjectMapFromActor change to automatically
  inject map_id into resource actions, eliminating the need for clients
  to provide map_id in their requests.
  """
  def add_context(conn, _resource) do
    # Actor is set by CheckJsonApiAuth using Ash.PlugHelpers.set_actor/2
    # For token-only auth, the actor is an ActorWithMap containing both user and map
    # The actor is passed to Ash actions and accessible via changeset.context[:private][:actor]
    # InjectMapFromActor extracts the map from ActorWithMap in the changeset
    conn
  end
end
