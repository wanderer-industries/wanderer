defmodule WandererApp.Api.AccessList do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("access_lists_v1")
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
      accept [:name, :description, :owner_id]
      primary?(true)

      argument :owner_id, :uuid, allow_nil?: false

      change manage_relationship(:owner_id, :owner, on_lookup: :relate, on_no_match: nil)
    end

    update :update do
      accept [:name, :description, :owner_id]
      primary?(true)
    end

    update :assign_owner do
      accept [:owner_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :owner, WandererApp.Api.Character do
      attribute_writable? true
    end

    has_many :members, WandererApp.Api.AccessListMember
  end
end
