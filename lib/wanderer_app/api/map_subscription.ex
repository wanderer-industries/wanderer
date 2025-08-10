defmodule WandererApp.Api.MapSubscription do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_subscriptions_v1")
  end

  json_api do
    type "map_subscriptions"

    includes([
      :map
    ])

    # Enable automatic filtering and sorting
    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_subscriptions")

      get(:read)
      index :read
    end
  end

  code_interface do
    define(:create, action: :create)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:all_active, action: :all_active)
    define(:all_by_map, action: :all_by_map)
    define(:active_by_map, action: :active_by_map)
    define(:destroy, action: :destroy)
    define(:cancel, action: :cancel)
    define(:expire, action: :expire)

    define(:update_plan, action: :update_plan)
    define(:update_characters_limit, action: :update_characters_limit)
    define(:update_hubs_limit, action: :update_hubs_limit)
    define(:update_active_till, action: :update_active_till)
    define(:update_auto_renew, action: :update_auto_renew)
  end

  actions do
    default_accept [
      :map_id,
      :plan,
      :active_till,
      :characters_limit,
      :hubs_limit,
      :auto_renew?
    ]

    defaults [:create, :read, :update, :destroy]

    read :all_active do
      prepare build(sort: [updated_at: :asc])

      filter(expr(status == :active))
    end

    read :all_by_map do
      argument(:map_id, :uuid, allow_nil?: false)

      prepare build(sort: [updated_at: :desc])

      filter(expr(map_id == ^arg(:map_id)))
    end

    read :active_by_map do
      argument(:map_id, :uuid, allow_nil?: false)

      prepare build(sort: [updated_at: :desc])

      filter(expr(map_id == ^arg(:map_id) and status == :active))
    end

    update :update_plan do
      accept [:plan]
    end

    update :update_characters_limit do
      accept [:characters_limit]
    end

    update :update_hubs_limit do
      accept [:hubs_limit]
    end

    update :update_active_till do
      accept [:active_till]
    end

    update :update_auto_renew do
      accept [:auto_renew?]
    end

    update :cancel do
      accept([])

      change(set_attribute(:status, :cancelled))
    end

    update :expire do
      accept([])

      change(set_attribute(:status, :expired))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :plan, :atom do
      default "alpha"

      constraints(
        one_of: [
          :alpha,
          :omega,
          :advanced,
          :custom
        ]
      )

      allow_nil?(true)
    end

    attribute :status, :atom do
      default "active"

      constraints(
        one_of: [
          :active,
          :cancelled,
          :expired
        ]
      )

      allow_nil?(true)
    end

    attribute :characters_limit, :integer do
      default(100)

      allow_nil?(true)
    end

    attribute :hubs_limit, :integer do
      default(10)

      allow_nil?(true)
    end

    attribute :active_till, :utc_datetime do
      allow_nil? true
    end

    attribute :auto_renew?, :boolean do
      allow_nil? false
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
      public? true
    end
  end
end
