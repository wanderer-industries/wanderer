defmodule WandererApp.Api.User do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak, AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("user_v1")
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

    defaults [:create, :read, :update, :destroy]

    update :update_last_map do
      accept([:last_map_id])
    end

    update :update_balance do
      require_atomic? false

      accept([:balance])
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
