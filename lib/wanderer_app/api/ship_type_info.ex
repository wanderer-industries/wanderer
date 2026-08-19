defmodule WandererApp.Api.ShipTypeInfo do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("ship_type_infos_v1")
  end

  # Defense in depth. This resource exposes no /api/v1 routes, but it remains
  # reachable as a relationship `include` and via any future route, so the
  # guarantee is enforced at the Ash layer rather than relying on the route
  # list staying empty. Token actors are forbidden outright; trusted internal
  # User/Character actors pass via the bypass.
  #
  # The criterion is `json_api do` — declaring a type is what makes a resource
  # reachable through the API surface (as an include/relationship target), with
  # or without routes of its own. Every resource that declares one is policed:
  # map, map_default_settings, map_solar_system, map_state, ship_type_info,
  # user. The remaining route-less resources (character, license, the
  # *_transaction/*_invite/*_ping/*_webhook_subscription/*_jumps set) declare no
  # `json_api` block at all, so they are unreachable from JSON:API and a policy
  # there would gate only internal callers.
  #
  # Safe for internal callers: the domain gate is `authorize :when_requested`,
  # which only authorizes when an `actor:` key is present
  # (ash/lib/ash/actions/helpers.ex:390). No internal caller of this resource
  # passes an actor, so actor-less reads/writes are unaffected.
  policies do
    bypass WandererApp.Api.Policies.MapScoped.trusted() do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  json_api do
    type "ship_type_info"

    routes do
      # No routes - this resource should not be exposed via API
    end
  end

  code_interface do
    define(:read,
      action: :read
    )

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_type_id,
      get_by: [:type_id],
      action: :read
    )

    define(:find_by_name, action: :find_by_name)
  end

  actions do
    default_accept [
      :type_id,
      :group_id,
      :group_name,
      :name,
      :description,
      :mass,
      :capacity,
      :volume
    ]

    defaults [:read, :destroy]

    update :update do
      require_atomic? false
    end

    create :create do
      primary? true
      upsert? true
      upsert_identity :type_id

      upsert_fields [
        :group_id,
        :group_name,
        :name,
        :description,
        :mass,
        :capacity,
        :volume
      ]
    end

    read :find_by_name do
      argument(:name, :string, allow_nil?: false)

      filter(expr(contains(name, string_downcase(^arg(:name)))))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type_id, :integer
    attribute :group_id, :integer
    attribute :group_name, :string
    attribute :name, :string
    attribute :description, :string
    attribute :mass, :string
    attribute :capacity, :string
    attribute :volume, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :type_id, [:type_id] do
      pre_check?(true)
    end
  end
end
