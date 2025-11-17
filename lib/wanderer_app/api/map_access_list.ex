defmodule WandererApp.Api.MapAccessList do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias WandererApp.Api.Changes.InjectMapFromActor

  postgres do
    repo(WandererApp.Repo)
    table("map_access_lists_v1")
  end

  json_api do
    type "map_access_lists"

    # Handle composite primary key
    primary_key do
      keys([:id])
    end

    includes([
      :map,
      :access_list
    ])

    # Enable automatic filtering and sorting
    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_access_lists")

      get(:read)
      index :read
      post(:create_with_map_injection)
      patch(:update)
      delete(:destroy)

      # Custom routes for specific queries
      get(:read_by_map, route: "/by_map/:map_id")
      get(:read_by_acl, route: "/by_acl/:acl_id")
    end
  end

  code_interface do
    define(:create_with_map_injection, action: :create_with_map_injection)

    define(:read_by_map,
      action: :read_by_map
    )

    define(:read_by_acl,
      action: :read_by_acl
    )
  end

  actions do
    default_accept [
      :access_list_id,
      :map_id
    ]

    # Default create action for relationship management
    # map_id is auto-set by manage_relationship
    create :create do
      primary? true
      accept [:access_list_id, :map_id]
    end

    # API v1 create action with map injection
    create :create_with_map_injection do
      accept [:access_list_id]
      change InjectMapFromActor
    end

    read :read do
      primary? true

      # Auto-filter by map_id from authenticated token
      prepare fn query, context ->
        case Map.get(context, :map) do
          %{id: map_id} ->
            Ash.Query.filter(query, expr(map_id == ^map_id))

          _ ->
            query
        end
      end

      pagination offset?: true,
                 default_limit: 100,
                 max_page_size: 500,
                 countable: true,
                 required?: false
    end

    defaults [:update, :destroy]

    read :read_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :read_by_acl do
      argument(:acl_id, :string, allow_nil?: false)
      filter(expr(access_list_id == ^arg(:acl_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map, primary_key?: true, allow_nil?: false, public?: true

    belongs_to :access_list, WandererApp.Api.AccessList,
      primary_key?: true,
      allow_nil?: false,
      public?: true
  end

  postgres do
    references do
      reference :map, on_delete: :delete
      reference :access_list, on_delete: :delete
    end
  end

  identities do
    identity :unique_map_acl, [:map_id, :access_list_id] do
      pre_check?(false)
    end
  end
end
