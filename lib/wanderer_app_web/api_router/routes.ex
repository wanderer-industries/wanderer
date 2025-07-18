defmodule WandererAppWeb.ApiRoutes do
  @moduledoc """
  Centralized API route definitions using structured RouteSpec.

  This module consolidates all API routes into a single version (v1)
  with full feature support including filtering, sorting, pagination,
  includes, and all CRUD operations.
  """

  alias WandererAppWeb.ApiRouter.RouteSpec

  @route_definitions %{
    "1" => [
      # Maps API - Full CRUD with all features
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: WandererAppWeb.MapAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination includes),
        metadata: %{
          auth_required: false,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List all maps with full feature set"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :id),
        controller: WandererAppWeb.MapAPIController,
        action: :show_v1,
        features: ~w(sparse_fieldsets includes),
        metadata: %{
          auth_required: false,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific map"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps),
        controller: WandererAppWeb.MapAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          error_status: 422,
          content_type: "application/vnd.api+json",
          description: "Create a new map"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps :id),
        controller: WandererAppWeb.MapAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update an existing map"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps :id),
        controller: WandererAppWeb.MapAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a map"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps :id duplicate),
        controller: WandererAppWeb.MapAPIController,
        action: :duplicate_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Duplicate an existing map"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps bulk),
        controller: WandererAppWeb.MapAPIController,
        action: :bulk_create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Bulk create maps"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps bulk),
        controller: WandererAppWeb.MapAPIController,
        action: :bulk_update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Bulk update maps"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps bulk),
        controller: WandererAppWeb.MapAPIController,
        action: :bulk_delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Bulk delete maps"
        }
      },

      # Characters API - Full CRUD with filtering and includes
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 characters),
        controller: WandererAppWeb.CharactersAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination includes),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List user characters"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 characters :id),
        controller: WandererAppWeb.CharactersAPIController,
        action: :show_v1,
        features: ~w(sparse_fieldsets includes),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific character"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 characters),
        controller: WandererAppWeb.CharactersAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :strict,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Create a new character"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 characters :id),
        controller: WandererAppWeb.CharactersAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update a character"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 characters :id),
        controller: WandererAppWeb.CharactersAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a character"
        }
      },

      # Map Systems API - Full CRUD with filtering and includes
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id systems),
        controller: WandererAppWeb.MapSystemAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination includes),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List systems for a map"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id systems :id),
        controller: WandererAppWeb.MapSystemAPIController,
        action: :show_v1,
        features: ~w(sparse_fieldsets includes),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific system"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps :map_id systems),
        controller: WandererAppWeb.MapSystemAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Create a new system"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps :map_id systems :id),
        controller: WandererAppWeb.MapSystemAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update a system"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps :map_id systems :id),
        controller: WandererAppWeb.MapSystemAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a system"
        }
      },

      # Map Connections API
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id connections),
        controller: WandererAppWeb.MapConnectionAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List connections for a map"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id connections :id),
        controller: WandererAppWeb.MapConnectionAPIController,
        action: :show_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific connection"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps :map_id connections),
        controller: WandererAppWeb.MapConnectionAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Create a new connection"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps :map_id connections :id),
        controller: WandererAppWeb.MapConnectionAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update a connection"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps :map_id connections :id),
        controller: WandererAppWeb.MapConnectionAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a connection"
        }
      },

      # Webhooks API
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id webhooks),
        controller: WandererAppWeb.MapWebhooksAPIController,
        action: :index_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List webhooks for a map"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id webhooks :id),
        controller: WandererAppWeb.MapWebhooksAPIController,
        action: :show_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific webhook"
        }
      },
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 maps :map_id webhooks),
        controller: WandererAppWeb.MapWebhooksAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Create a new webhook"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 maps :map_id webhooks :id),
        controller: WandererAppWeb.MapWebhooksAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update a webhook"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 maps :map_id webhooks :id),
        controller: WandererAppWeb.MapWebhooksAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Delete a webhook"
        }
      },

      # Real-time Events API
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps :map_id events stream),
        controller: WandererAppWeb.Api.EventsController,
        action: :stream_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :relaxed,
          success_status: 200,
          content_type: "text/event-stream",
          description: "Stream real-time events for a map"
        }
      },

      # Access Lists API
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 acls),
        controller: WandererAppWeb.AccessListAPIController,
        action: :index_v1,
        features: ~w(filtering sorting pagination),
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "List access control lists"
        }
      },
      %RouteSpec{
        verb: :get,
        path: ~w(api v1 acls :id),
        controller: WandererAppWeb.AccessListAPIController,
        action: :show_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Show a specific access list"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 acls :id),
        controller: WandererAppWeb.AccessListAPIController,
        action: :update_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update an access list"
        }
      },

      # ACL Members API
      %RouteSpec{
        verb: :post,
        path: ~w(api v1 acls :acl_id members),
        controller: WandererAppWeb.AccessListMemberAPIController,
        action: :create_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 201,
          content_type: "application/vnd.api+json",
          description: "Add a member to an access list"
        }
      },
      %RouteSpec{
        verb: :put,
        path: ~w(api v1 acls :acl_id members :member_id),
        controller: WandererAppWeb.AccessListMemberAPIController,
        action: :update_role_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 200,
          content_type: "application/vnd.api+json",
          description: "Update a member's role"
        }
      },
      %RouteSpec{
        verb: :delete,
        path: ~w(api v1 acls :acl_id members :member_id),
        controller: WandererAppWeb.AccessListMemberAPIController,
        action: :delete_v1,
        features: [],
        metadata: %{
          auth_required: true,
          rate_limit: :standard,
          success_status: 204,
          content_type: "application/vnd.api+json",
          description: "Remove a member from an access list"
        }
      }
    ]
  }

  @deprecated_versions []
  @sunset_dates %{}

  def table, do: @route_definitions
  def deprecated_versions, do: @deprecated_versions
  def sunset_date(version), do: Map.get(@sunset_dates, version)

  @doc """
  Get all routes for a specific version.
  """
  def routes_for_version(version) do
    Map.get(@route_definitions, version, [])
  end

  @doc """
  Get all available versions.
  """
  def available_versions do
    Map.keys(@route_definitions)
  end

  @doc """
  Check if a version is deprecated.
  """
  def deprecated?(version) do
    version in @deprecated_versions
  end

  @doc """
  Validate all route definitions on module load.
  """
  def validate_all_routes do
    Enum.reduce(@route_definitions, [], fn {version, routes}, errors ->
      version_errors =
        Enum.reduce(routes, [], fn route_spec, acc ->
          case RouteSpec.validate(route_spec) do
            {:ok, _} -> acc
            {:error, error} -> [{version, route_spec, error} | acc]
          end
        end)

      errors ++ version_errors
    end)
  end
end
