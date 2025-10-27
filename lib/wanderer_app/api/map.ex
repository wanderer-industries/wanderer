defmodule WandererApp.Api.Map do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Ash.Resource.Change.Builtins

  postgres do
    repo(WandererApp.Repo)
    table("maps_v1")
  end

  json_api do
    type "maps"

    # Include relationships for compound documents
    includes([
      :owner,
      :characters,
      :acls
    ])

    # Enable filtering and sorting
    derive_filter?(true)
    derive_sort?(true)

    # Routes configuration
    routes do
      base("/maps")
      get(:by_slug, route: "/:slug")
      index :read
      post(:new)
      patch(:update)
      delete(:destroy)

      # Custom action for map duplication
      post(:duplicate, route: "/:id/duplicate")
    end
  end

  code_interface do
    define(:available, action: :available)
    define(:get_map_by_slug, action: :by_slug, args: [:slug])
    define(:new, action: :new)
    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_acls, action: :update_acls)
    define(:update_hubs, action: :update_hubs)
    define(:update_options, action: :update_options)
    define(:assign_owner, action: :assign_owner)
    define(:mark_as_deleted, action: :mark_as_deleted)
    define(:update_api_key, action: :update_api_key)
    define(:toggle_webhooks, action: :toggle_webhooks)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:duplicate, action: :duplicate)
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

    update :update_options do
      accept [:options]
    end

    update :mark_as_deleted do
      accept([])

      change(set_attribute(:deleted, true))
    end

    update :update_api_key do
      accept [:public_api_key]
    end

    update :toggle_webhooks do
      accept [:webhooks_enabled]
    end

    create :duplicate do
      accept [:name, :description, :scope, :only_tracked_characters]

      argument :source_map_id, :uuid, allow_nil?: false
      argument :copy_acls, :boolean, default: true
      argument :copy_user_settings, :boolean, default: true
      argument :copy_signatures, :boolean, default: true

      # Set defaults from source map before creation
      change fn changeset, context ->
        source_map_id = Ash.Changeset.get_argument(changeset, :source_map_id)

        case WandererApp.Api.Map.by_id(source_map_id) do
          {:ok, source_map} ->
            # Use provided description or fall back to source map description
            description =
              Ash.Changeset.get_attribute(changeset, :description) || source_map.description

            changeset
            |> Ash.Changeset.change_attribute(:description, description)
            |> Ash.Changeset.change_attribute(:scope, source_map.scope)
            |> Ash.Changeset.change_attribute(
              :only_tracked_characters,
              source_map.only_tracked_characters
            )
            |> Ash.Changeset.change_attribute(:owner_id, context.actor.id)
            |> Ash.Changeset.change_attribute(
              :slug,
              generate_unique_slug(Ash.Changeset.get_attribute(changeset, :name))
            )

          {:error, _} ->
            Ash.Changeset.add_error(changeset,
              field: :source_map_id,
              message: "Source map not found"
            )
        end
      end

      # Copy related data after creation
      change Builtins.after_action(fn changeset, new_map, context ->
               source_map_id = Ash.Changeset.get_argument(changeset, :source_map_id)
               copy_acls = Ash.Changeset.get_argument(changeset, :copy_acls)
               copy_user_settings = Ash.Changeset.get_argument(changeset, :copy_user_settings)
               copy_signatures = Ash.Changeset.get_argument(changeset, :copy_signatures)

               case WandererApp.Map.Operations.Duplication.duplicate_map(
                      source_map_id,
                      new_map,
                      copy_acls: copy_acls,
                      copy_user_settings: copy_user_settings,
                      copy_signatures: copy_signatures
                    ) do
                 {:ok, _result} ->
                   {:ok, new_map}

                 {:error, error} ->
                   {:error, error}
               end
             end)
    end
  end

  # Generate a unique slug from map name
  defp generate_unique_slug(name) do
    base_slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    # Add timestamp to ensure uniqueness
    timestamp = System.system_time(:millisecond) |> Integer.to_string()
    "#{base_slug}-#{timestamp}"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints trim?: false, max_length: 20, min_length: 3, allow_empty?: false
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints trim?: false, max_length: 40, min_length: 3, allow_empty?: false
    end

    attribute :description, :string do
      public? true
    end

    attribute :personal_note, :string do
      public? true
    end

    attribute :public_api_key, :string do
      allow_nil? true
    end

    attribute :hubs, {:array, :string} do
      allow_nil?(true)

      default([])
    end

    attribute :scope, :atom do
      default "wormholes"
      public? true

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

    attribute :options, :string do
      allow_nil? true
    end

    attribute :webhooks_enabled, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
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
      public? true
    end

    many_to_many :characters, WandererApp.Api.Character do
      through WandererApp.Api.MapCharacterSettings
      source_attribute_on_join_resource :map_id
      destination_attribute_on_join_resource :character_id
      public? true
    end

    many_to_many :acls, WandererApp.Api.AccessList do
      through WandererApp.Api.MapAccessList
      source_attribute_on_join_resource :map_id
      destination_attribute_on_join_resource :access_list_id
      public? true
    end

    has_many :transactions, WandererApp.Api.MapTransaction do
      public? false
    end
  end
end
