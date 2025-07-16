defmodule WandererAppWeb.ApiRouter do
  @moduledoc """
  Version-aware API router that handles routing based on API version.

  This module provides:
  - Version-specific routing logic
  - Backward compatibility handling
  - Feature flag support per version
  - Automatic JSON:API compliance for newer versions
  """

  use Phoenix.Router

  alias WandererAppWeb.Plugs.ApiVersioning

  # Import helpers for version-aware routing
  import WandererAppWeb.ApiRouterHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    version = conn.assigns[:api_version] || "1.2"

    # Route based on version
    case version do
      v when v in ["1.0"] ->
        route_v1_0(conn)

      v when v in ["1.1"] ->
        route_v1_1(conn)

      v when v in ["1.2"] ->
        route_v1_2(conn)

      _ ->
        # Default to latest version
        route_v1_2(conn)
    end
  end

  # Version 1.0 routing (legacy compatibility)
  defp route_v1_0(conn) do
    case {conn.method, conn.path_info} do
      # Maps API - basic CRUD only
      {"GET", ["api", "maps"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :index_v1_0)

      {"GET", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :show_v1_0, %{"id" => map_id})

      {"POST", ["api", "maps"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :create_v1_0)

      {"PUT", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :update_v1_0, %{"id" => map_id})

      {"DELETE", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :delete_v1_0, %{"id" => map_id})

      # Characters API - basic CRUD only
      {"GET", ["api", "characters"]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :index_v1_0)

      {"GET", ["api", "characters", character_id]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :show_v1_0, %{
          "id" => character_id
        })

      # Systems API - read only in v1.0
      {"GET", ["api", "maps", map_id, "systems"]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :index_v1_0, %{
          "map_id" => map_id
        })

      {"GET", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :show_v1_0, %{
          "map_id" => map_id,
          "id" => system_id
        })

      _ ->
        send_not_supported_error(conn, "1.0")
    end
  end

  # Version 1.1 routing (adds filtering, sorting, sparse fieldsets)
  defp route_v1_1(conn) do
    case {conn.method, conn.path_info} do
      # Enhanced Maps API with filtering and sorting
      {"GET", ["api", "maps"]} ->
        route_with_enhancements(conn, WandererAppWeb.MapAPIController, :index_v1_1, [
          "filtering",
          "sorting",
          "pagination"
        ])

      {"GET", ["api", "maps", map_id]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapAPIController,
          :show_v1_1,
          ["sparse_fieldsets"],
          %{"id" => map_id}
        )

      {"POST", ["api", "maps"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :create_v1_1)

      {"PUT", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :update_v1_1, %{"id" => map_id})

      {"DELETE", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :delete_v1_1, %{"id" => map_id})

      # Enhanced Characters API
      {"GET", ["api", "characters"]} ->
        route_with_enhancements(conn, WandererAppWeb.CharactersAPIController, :index_v1_1, [
          "filtering",
          "sorting"
        ])

      {"GET", ["api", "characters", character_id]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.CharactersAPIController,
          :show_v1_1,
          ["sparse_fieldsets"],
          %{"id" => character_id}
        )

      {"POST", ["api", "characters"]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :create_v1_1)

      # Enhanced Systems API with full CRUD
      {"GET", ["api", "maps", map_id, "systems"]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapSystemAPIController,
          :index_v1_1,
          ["filtering", "sorting"],
          %{"map_id" => map_id}
        )

      {"GET", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :show_v1_1, %{
          "map_id" => map_id,
          "id" => system_id
        })

      {"POST", ["api", "maps", map_id, "systems"]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :create_v1_1, %{
          "map_id" => map_id
        })

      {"PUT", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :update_v1_1, %{
          "map_id" => map_id,
          "id" => system_id
        })

      {"DELETE", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :delete_v1_1, %{
          "map_id" => map_id,
          "id" => system_id
        })

      # Connections API
      {"GET", ["api", "maps", map_id, "connections"]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapConnectionAPIController,
          :index_v1_1,
          ["filtering"],
          %{"map_id" => map_id}
        )

      _ ->
        send_not_supported_error(conn, "1.1")
    end
  end

  # Version 1.2 routing (adds includes, bulk operations, webhooks, real-time events)
  defp route_v1_2(conn) do
    case {conn.method, conn.path_info} do
      # Full-featured Maps API with includes and bulk operations
      {"GET", ["api", "maps"]} ->
        route_with_enhancements(conn, WandererAppWeb.MapAPIController, :index_v1_2, [
          "filtering",
          "sorting",
          "pagination",
          "includes"
        ])

      {"GET", ["api", "maps", map_id]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapAPIController,
          :show_v1_2,
          ["sparse_fieldsets", "includes"],
          %{"id" => map_id}
        )

      {"POST", ["api", "maps"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :create_v1_2)

      {"PUT", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :update_v1_2, %{"id" => map_id})

      {"DELETE", ["api", "maps", map_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :delete_v1_2, %{"id" => map_id})

      # Bulk operations for maps
      {"POST", ["api", "maps", "bulk"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :bulk_create_v1_2)

      {"PUT", ["api", "maps", "bulk"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :bulk_update_v1_2)

      {"DELETE", ["api", "maps", "bulk"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :bulk_delete_v1_2)

      # Map duplication
      {"POST", ["api", "maps", map_id, "duplicate"]} ->
        route_to_controller(conn, WandererAppWeb.MapAPIController, :duplicate_v1_2, %{
          "id" => map_id
        })

      # Enhanced Characters API with full features
      {"GET", ["api", "characters"]} ->
        route_with_enhancements(conn, WandererAppWeb.CharactersAPIController, :index_v1_2, [
          "filtering",
          "sorting",
          "includes"
        ])

      {"GET", ["api", "characters", character_id]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.CharactersAPIController,
          :show_v1_2,
          ["sparse_fieldsets", "includes"],
          %{"id" => character_id}
        )

      {"POST", ["api", "characters"]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :create_v1_2)

      {"PUT", ["api", "characters", character_id]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :update_v1_2, %{
          "id" => character_id
        })

      {"DELETE", ["api", "characters", character_id]} ->
        route_to_controller(conn, WandererAppWeb.CharactersAPIController, :delete_v1_2, %{
          "id" => character_id
        })

      # Systems API with full JSON:API compliance
      {"GET", ["api", "maps", map_id, "systems"]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapSystemAPIController,
          :index_v1_2,
          ["filtering", "sorting", "includes"],
          %{"map_id" => map_id}
        )

      {"GET", ["api", "maps", map_id, "systems", system_id]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapSystemAPIController,
          :show_v1_2,
          ["sparse_fieldsets", "includes"],
          %{"map_id" => map_id, "id" => system_id}
        )

      {"POST", ["api", "maps", map_id, "systems"]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :create_v1_2, %{
          "map_id" => map_id
        })

      {"PUT", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :update_v1_2, %{
          "map_id" => map_id,
          "id" => system_id
        })

      {"DELETE", ["api", "maps", map_id, "systems", system_id]} ->
        route_to_controller(conn, WandererAppWeb.MapSystemAPIController, :delete_v1_2, %{
          "map_id" => map_id,
          "id" => system_id
        })

      # Connections API with full features
      {"GET", ["api", "maps", map_id, "connections"]} ->
        route_with_enhancements(
          conn,
          WandererAppWeb.MapConnectionAPIController,
          :index_v1_2,
          ["filtering", "sorting"],
          %{"map_id" => map_id}
        )

      {"GET", ["api", "maps", map_id, "connections", connection_id]} ->
        route_to_controller(conn, WandererAppWeb.MapConnectionAPIController, :show_v1_2, %{
          "map_id" => map_id,
          "id" => connection_id
        })

      {"POST", ["api", "maps", map_id, "connections"]} ->
        route_to_controller(conn, WandererAppWeb.MapConnectionAPIController, :create_v1_2, %{
          "map_id" => map_id
        })

      {"PUT", ["api", "maps", map_id, "connections", connection_id]} ->
        route_to_controller(conn, WandererAppWeb.MapConnectionAPIController, :update_v1_2, %{
          "map_id" => map_id,
          "id" => connection_id
        })

      {"DELETE", ["api", "maps", map_id, "connections", connection_id]} ->
        route_to_controller(conn, WandererAppWeb.MapConnectionAPIController, :delete_v1_2, %{
          "map_id" => map_id,
          "id" => connection_id
        })

      # Webhooks API (v1.2+ only)
      {"GET", ["api", "maps", map_id, "webhooks"]} ->
        route_to_controller(conn, WandererAppWeb.MapWebhooksAPIController, :index, %{
          "map_identifier" => map_id
        })

      {"GET", ["api", "maps", map_id, "webhooks", webhook_id]} ->
        route_to_controller(conn, WandererAppWeb.MapWebhooksAPIController, :show, %{
          "map_identifier" => map_id,
          "id" => webhook_id
        })

      {"POST", ["api", "maps", map_id, "webhooks"]} ->
        route_to_controller(conn, WandererAppWeb.MapWebhooksAPIController, :create, %{
          "map_identifier" => map_id
        })

      {"PUT", ["api", "maps", map_id, "webhooks", webhook_id]} ->
        route_to_controller(conn, WandererAppWeb.MapWebhooksAPIController, :update, %{
          "map_identifier" => map_id,
          "id" => webhook_id
        })

      {"DELETE", ["api", "maps", map_id, "webhooks", webhook_id]} ->
        route_to_controller(conn, WandererAppWeb.MapWebhooksAPIController, :delete, %{
          "map_identifier" => map_id,
          "id" => webhook_id
        })

      # Real-time events API (v1.2+ only)
      {"GET", ["api", "maps", map_id, "events", "stream"]} ->
        route_to_controller(conn, WandererAppWeb.Api.EventsController, :stream, %{
          "map_identifier" => map_id
        })

      # Access Lists API
      {"GET", ["api", "acls"]} ->
        route_with_enhancements(conn, WandererAppWeb.MapAccessListAPIController, :index_v1_2, [
          "filtering",
          "sorting"
        ])

      {"GET", ["api", "acls", acl_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAccessListAPIController, :show, %{
          "id" => acl_id
        })

      {"PUT", ["api", "acls", acl_id]} ->
        route_to_controller(conn, WandererAppWeb.MapAccessListAPIController, :update, %{
          "id" => acl_id
        })

      # ACL Members API
      {"POST", ["api", "acls", acl_id, "members"]} ->
        route_to_controller(conn, WandererAppWeb.AccessListMemberAPIController, :create, %{
          "acl_id" => acl_id
        })

      {"PUT", ["api", "acls", acl_id, "members", member_id]} ->
        route_to_controller(conn, WandererAppWeb.AccessListMemberAPIController, :update_role, %{
          "acl_id" => acl_id,
          "member_id" => member_id
        })

      {"DELETE", ["api", "acls", acl_id, "members", member_id]} ->
        route_to_controller(conn, WandererAppWeb.AccessListMemberAPIController, :delete, %{
          "acl_id" => acl_id,
          "member_id" => member_id
        })

      _ ->
        send_not_supported_error(conn, "1.2")
    end
  end

  # Helper function to route to controller with path params
  defp route_to_controller(conn, controller, action, path_params \\ %{}) do
    conn
    |> Map.put(:path_params, path_params)
    |> Map.update!(:params, fn params -> Map.merge(params, path_params) end)
    |> controller.call(controller.init(action))
  end

  # Helper function to add version-specific enhancements
  defp route_with_enhancements(conn, controller, action, features, path_params \\ %{}) do
    version = conn.assigns[:api_version]

    conn
    |> add_version_features(features, version)
    |> route_to_controller(controller, action, path_params)
  end

  defp add_version_features(conn, features, version) do
    # Add feature flags based on version capabilities
    version_config = ApiVersioning.get_version_config(version)

    Enum.reduce(features, conn, fn feature, acc ->
      feature_atom = String.to_atom(feature)

      if feature_atom in version_config.features do
        Phoenix.Conn.assign(acc, :"supports_#{feature}", true)
      else
        Phoenix.Conn.assign(acc, :"supports_#{feature}", false)
      end
    end)
    |> Phoenix.Conn.assign(:version_config, version_config)
  end

  defp send_not_supported_error(conn, version) do
    error_response = %{
      error: "Endpoint not supported in API version #{version}",
      method: conn.method,
      path: "/" <> Enum.join(conn.path_info, "/"),
      supported_versions: ApiVersioning.get_migration_path(version),
      upgrade_guide: "https://docs.wanderer.com/api/migration/#{version}",
      timestamp: DateTime.utc_now()
    }

    conn
    |> Phoenix.Conn.put_status(404)
    |> Phoenix.Conn.put_resp_content_type("application/json")
    |> Phoenix.Conn.send_resp(404, Jason.encode!(error_response))
    |> Phoenix.Conn.halt()
  end
end
