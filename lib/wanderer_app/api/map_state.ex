defmodule WandererApp.Api.MapState do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_state_v1")
  end

  # Defense in depth. This resource exposes no /api/v1 routes, but it remains
  # reachable as a relationship `include` and via any future route, so the
  # guarantee is enforced at the Ash layer rather than relying on the route
  # list staying empty. Token actors are forbidden outright; trusted internal
  # User/Character actors pass via the bypass.
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
    type "map_states"

    routes do
      # No routes - this resource should not be exposed via API
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    define(:get_last_active, action: :last_active, args: [:from])

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map_id,
      get_by: [:map_id],
      action: :read
    )
  end

  actions do
    default_accept [
      :map_id,
      :systems_last_activity,
      :connections_eol_time,
      :connections_start_time
    ]

    defaults [:read, :destroy]

    update :update do
      require_atomic? false
    end

    create :create do
      primary? true
      upsert? true
      upsert_identity :uniq_map_id

      upsert_fields [
        :systems_last_activity,
        :connections_eol_time,
        :connections_start_time,
        :updated_at
      ]
    end

    read :last_active do
      argument(:from, :utc_datetime, allow_nil?: false)

      filter(expr(updated_at > ^arg(:from)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :systems_last_activity, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
    end

    attribute :connections_start_time, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
    end

    attribute :connections_eol_time, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end
  end

  identities do
    identity(:uniq_map_id, [:map_id])
  end
end
