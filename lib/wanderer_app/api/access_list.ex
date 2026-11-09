defmodule WandererApp.Api.AccessList do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("access_lists_v1")
  end

  # Token actors get read access to ACLs linked to their map and nothing more.
  # ACL administration is a session/internal concern, so all token writes are
  # hard-forbidden (403) rather than filter-scoped -- unlike map-owned
  # resources, there is no "your own ACL" a map token may legitimately mutate.
  policies do
    bypass WandererApp.Api.Policies.MapScoped.trusted() do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if WandererApp.Api.Policies.AclScoped.AclInTokenMap
    end

    policy action_type([:create, :update, :destroy]) do
      forbid_if always()
    end
  end

  json_api do
    type "access_lists"

    includes([:owner, :members])

    default_fields([
      :name,
      :description
    ])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/access_lists")
      get(:read)
      index :read
      post(:new)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:available, action: :available)
    define(:new, action: :new)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )
  end

  actions do
    default_accept [
      :name,
      :description,
      :owner_id
    ]

    defaults [:create, :read, :destroy]

    read :available do
      prepare WandererApp.Api.Preparations.FilterAclsByRoles
    end

    create :new do
      # Added :api_key to the accepted attributes
      accept [:name, :description, :owner_id, :api_key]
      primary?(true)
    end

    update :update do
      accept [:name, :description, :owner_id, :api_key]
      primary?(true)
      require_atomic? false
    end

    update :assign_owner do
      accept [:owner_id]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    # Note: api_key intentionally not public for security
    attribute :api_key, :string do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :owner, WandererApp.Api.Character do
      attribute_writable? true
      public? true
    end

    has_many :members, WandererApp.Api.AccessListMember do
      public? true
    end

    # Inverse of MapAccessList.access_list. Required so the AclScoped read
    # policy can express `exists(map_access_lists, map_id == ^map_id)`.
    # Kept private: this is a policy-internal join, not part of the public
    # filter surface for /api/v1/access_lists.
    has_many :map_access_lists, WandererApp.Api.MapAccessList do
      public? false
    end
  end
end
