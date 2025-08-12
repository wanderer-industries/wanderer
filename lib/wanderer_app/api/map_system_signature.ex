defmodule WandererApp.Api.MapSystemSignature do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_system_signatures_v1")
  end

  json_api do
    type "map_system_signatures"

    includes([:system])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_system_signatures")
      get(:read)
      index :read
      delete(:destroy)
    end
  end

  code_interface do
    define(:all_active, action: :all_active)
    define(:create, action: :create)
    define(:destroy, action: :destroy)
    define(:update, action: :update)
    define(:update_linked_system, action: :update_linked_system)
    define(:update_type, action: :update_type)
    define(:update_group, action: :update_group)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_system_id, action: :by_system_id, args: [:system_id])
    define(:by_system_id_all, action: :by_system_id_all, args: [:system_id])

    define(:by_system_id_and_eve_ids,
      action: :by_system_id_and_eve_ids,
      args: [:system_id, :eve_ids]
    )

    define(:by_linked_system_id, action: :by_linked_system_id, args: [:linked_system_id])

    define(:by_deleted_and_updated_before!,
      action: :by_deleted_and_updated_before,
      args: [:deleted, :updated_before]
    )
  end

  actions do
    default_accept [
      :system_id,
      :eve_id,
      :character_eve_id,
      :name,
      :temporary_name,
      :description,
      :kind,
      :group,
      :type,
      :deleted,
      :custom_info
    ]

    defaults [:destroy]

    read :read do
      primary?(true)

      pagination offset?: true,
                 default_limit: 50,
                 max_page_size: 200,
                 countable: true,
                 required?: false
    end

    read :all_active do
      prepare build(sort: [updated_at: :desc])
    end

    create :create do
      primary? true
      upsert? true
      upsert_identity :uniq_system_eve_id

      upsert_fields [
        :system_id,
        :eve_id
      ]

      accept [
        :system_id,
        :eve_id,
        :character_eve_id,
        :name,
        :temporary_name,
        :description,
        :kind,
        :group,
        :type,
        :custom_info,
        :deleted
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
        :temporary_name,
        :description,
        :kind,
        :group,
        :type,
        :custom_info,
        :deleted,
        :update_forced_at
      ]

      primary? true
      require_atomic? false
    end

    update :update_linked_system do
      accept [:linked_system_id]
    end

    update :update_type do
      accept [:type]
    end

    update :update_group do
      accept [:group]
    end

    read :by_system_id do
      argument(:system_id, :string, allow_nil?: false)

      filter(expr(system_id == ^arg(:system_id) and deleted == false))
    end

    read :by_system_id_all do
      argument(:system_id, :string, allow_nil?: false)
      filter(expr(system_id == ^arg(:system_id)))
    end

    read :by_system_id_and_eve_ids do
      argument(:system_id, :string, allow_nil?: false)
      argument(:eve_ids, {:array, :string}, allow_nil?: false)
      filter(expr(system_id == ^arg(:system_id) and eve_id in ^arg(:eve_ids)))
    end

    read :by_linked_system_id do
      argument(:linked_system_id, :integer, allow_nil?: false)

      filter(expr(linked_system_id == ^arg(:linked_system_id)))
    end

    read :by_deleted_and_updated_before do
      argument(:deleted, :boolean, allow_nil?: false)
      argument(:updated_before, :utc_datetime, allow_nil?: false)

      filter(expr(deleted == ^arg(:deleted) and updated_at < ^arg(:updated_before)))
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

    attribute :temporary_name, :string do
      allow_nil? true
    end

    attribute :type, :string do
      allow_nil? true
    end

    attribute :linked_system_id, :integer do
      allow_nil? true
    end

    attribute :kind, :string
    attribute :group, :string

    attribute :custom_info, :string do
      allow_nil? true
    end

    attribute :deleted, :boolean do
      allow_nil? false
      default false
    end

    attribute :update_forced_at, :utc_datetime do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
      public? true
    end
  end

  identities do
    identity :uniq_system_eve_id, [:system_id, :eve_id]
  end

  @derive {Jason.Encoder,
           only: [
             :id,
             :system_id,
             :eve_id,
             :character_eve_id,
             :name,
             :temporary_name,
             :description,
             :type,
             :linked_system_id,
             :kind,
             :group,
             :custom_info,
             :deleted,
             :inserted_at,
             :updated_at
           ]}
end
