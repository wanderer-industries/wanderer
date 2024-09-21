defmodule WandererApp.Api.MapSystemSignature do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_system_signatures_v1")
  end

  code_interface do
    define(:all_active, action: :all_active)
    define(:create, action: :create)
    define(:update, action: :update)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_system_id, action: :by_system_id, args: [:system_id])
  end

  actions do
    default_accept [
      :system_id,
      :eve_id,
      :character_eve_id,
      :name,
      :description,
      :kind,
      :group,
      :custom_info
    ]

    defaults [:read, :destroy]

    read :all_active do
      prepare build(sort: [updated_at: :desc])
    end

    create :create do
      primary? true

      accept [
        :system_id,
        :eve_id,
        :character_eve_id,
        :name,
        :description,
        :kind,
        :group,
        :custom_info
      ]

      argument :system_id, :uuid, allow_nil?: false

      change manage_relationship(:system_id, :system, on_lookup: :relate, on_no_match: nil)
    end

    update :update do
      accept [
        :system_id,
        :eve_id,
        :character_eve_id,
        :name,
        :description,
        :kind,
        :group,
        :custom_info
      ]

      primary? true
      require_atomic? false
    end

    read :by_system_id do
      argument(:system_id, :string, allow_nil?: false)

      filter(expr(system_id == ^arg(:system_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :eve_id, :string do
      allow_nil? false
    end

    attribute :character_eve_id, :string do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? true
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :custom_info, :string do
      allow_nil? true
    end

    attribute :kind, :string
    attribute :group, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
    end
  end

  identities do
    identity :uniq_system_eve_id, [:system_id, :eve_id]
  end
end
