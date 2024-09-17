defmodule WandererApp.Api.Map do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("maps_v1")
  end

  code_interface do
    define(:available, action: :available)
    define(:get_map_by_slug, action: :by_slug, args: [:slug])
    define(:new, action: :new)
    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_acls, action: :update_acls)
    define(:update_hubs, action: :update_hubs)
    define(:assign_owner, action: :assign_owner)
    define(:mark_as_deleted, action: :mark_as_deleted)

    define(:by_id,
      get_by: [:id],
      action: :read
    )
  end

  calculations do
    calculate :user_permissions, :integer, {WandererApp.Api.Calculations.CalcMapPermissions, []}
    calculate :balance, :float, expr(transactions_amount_in - transactions_amount_out)
  end

  aggregates do
    sum :transactions_amount_in, :transactions, :amount do
      default 0.0
      filter type: :in
    end

    sum :transactions_amount_out, :transactions, :amount do
      default 0.0
      filter type: :out
    end
  end

  actions do
    defaults [:create, :read, :destroy]

    read :by_slug do
      get? true
      argument :slug, :string, allow_nil?: false

      filter expr(slug == ^arg(:slug))
    end

    read :available do
      prepare WandererApp.Api.Preparations.FilterMapsByRoles
    end

    create :new do
      accept [:name, :slug, :description, :scope, :only_tracked_characters, :owner_id]
      primary?(true)

      argument :owner_id, :uuid, allow_nil?: false
      argument :owner_id_text_input, :string, allow_nil?: true
      argument :create_default_acl, :boolean, allow_nil?: true
      argument :acls, {:array, :uuid}, allow_nil?: true
      argument :acls_text_input, :string, allow_nil?: true
      argument :scope_text_input, :string, allow_nil?: true
      argument :acls_empty_selection, :string, allow_nil?: true

      change manage_relationship(:owner_id, :owner, on_lookup: :relate, on_no_match: nil)
      change manage_relationship(:acls, type: :append_and_remove)
      change WandererApp.Api.Changes.SlugifyName
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :slug, :description, :scope, :only_tracked_characters, :owner_id]

      argument :owner_id_text_input, :string, allow_nil?: true
      argument :acls_text_input, :string, allow_nil?: true
      argument :scope_text_input, :string, allow_nil?: true
      argument :acls_empty_selection, :string, allow_nil?: true
      argument :acls, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:acls,
               on_lookup: :relate,
               on_no_match: :create,
               on_missing: :unrelate
             )

      change WandererApp.Api.Changes.SlugifyName
    end

    update :update_acls do
      require_atomic? false

      argument :acls, {:array, :uuid} do
        allow_nil? false
      end

      change manage_relationship(:acls, type: :append_and_remove)
    end

    update :assign_owner do
      accept [:owner_id]
    end

    update :update_hubs do
      accept [:hubs]
    end

    update :mark_as_deleted do
      accept([])

      change(set_attribute(:deleted, true))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints trim?: false, max_length: 20, min_length: 3, allow_empty?: false
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints trim?: false, max_length: 40, min_length: 3, allow_empty?: false
    end

    attribute :description, :string
    attribute :personal_note, :string

    attribute :hubs, {:array, :string} do
      allow_nil?(true)

      default([])
    end

    attribute :scope, :atom do
      default "wormholes"

      constraints(
        one_of: [
          :wormholes,
          :stargates,
          :none,
          :all
        ]
      )

      allow_nil?(false)
    end

    attribute :deleted, :boolean do
      default(false)
      allow_nil?(true)
    end

    attribute :only_tracked_characters, :boolean do
      default(false)
      allow_nil?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :owner, WandererApp.Api.Character do
      attribute_writable? true
    end

    many_to_many :characters, WandererApp.Api.Character do
      through WandererApp.Api.MapCharacterSettings
      source_attribute_on_join_resource :map_id
      destination_attribute_on_join_resource :character_id
    end

    many_to_many :acls, WandererApp.Api.AccessList do
      through WandererApp.Api.MapAccessList
      source_attribute_on_join_resource :map_id
      destination_attribute_on_join_resource :access_list_id
    end

    has_many :transactions, WandererApp.Api.MapTransaction
  end
end
