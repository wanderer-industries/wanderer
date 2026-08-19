defmodule WandererApp.Api.User do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshCloak, AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("user_v1")
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
    type "users"

    # Only expose safe, non-sensitive attributes
    includes([:characters])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      # No routes - this resource should not be exposed via API
    end
  end

  code_interface do
    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_hash,
      get_by: [:hash],
      action: :read
    )

    define(:update_last_map,
      action: :update_last_map
    )

    define(:update_balance,
      action: :update_balance
    )
  end

  actions do
    default_accept [
      :name,
      :hash
    ]

    defaults [:create, :read, :destroy]

    update :update do
      require_atomic? false
    end

    update :update_last_map do
      accept([:last_map_id])
      require_atomic? false
    end

    update :update_balance do
      require_atomic? false

      accept([:balance])

      validate compare(:balance, greater_than_or_equal_to: 0),
        message: "balance cannot be negative"
    end
  end

  cloak do
    vault(WandererApp.Vault)

    attributes([:balance])
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :hash, :string
    attribute :last_map_id, :uuid

    attribute :balance, :float do
      default 0.0

      allow_nil?(true)
    end
  end

  relationships do
    has_many :characters, WandererApp.Api.Character do
      public? true
    end
  end

  identities do
    identity :unique_hash, [:hash] do
      pre_check?(false)
    end
  end
end
