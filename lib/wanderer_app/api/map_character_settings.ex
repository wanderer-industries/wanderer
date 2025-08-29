defmodule WandererApp.Api.MapCharacterSettings do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak, AshJsonApi.Resource]

  @derive {Jason.Encoder,
           only: [
             :id,
             :map_id,
             :character_id,
             :tracked,
             :followed,
             :inserted_at,
             :updated_at
           ]}

  postgres do
    repo(WandererApp.Repo)
    table("map_character_settings_v1")
  end

  json_api do
    type "map_character_settings"

    includes([:map, :character])

    derive_filter?(true)
    derive_sort?(true)

    primary_key do
      keys([:id])
    end

    routes do
      base("/map_character_settings")
      get(:read)
      index :read
    end
  end

  code_interface do
    define(:read_by_map, action: :read_by_map)
    define(:read_by_map_and_character, action: :read_by_map_and_character)
    define(:by_map_filtered, action: :by_map_filtered)
    define(:tracked_by_map_filtered, action: :tracked_by_map_filtered)
    define(:tracked_by_character, action: :tracked_by_character)
    define(:tracked_by_map_all, action: :tracked_by_map_all)
    define(:create, action: :create)
    define(:update, action: :update)
    define(:track, action: :track)
    define(:untrack, action: :untrack)
    define(:follow, action: :follow)
    define(:unfollow, action: :unfollow)
    define(:destroy, action: :destroy)
  end

  actions do
    default_accept [
      :map_id,
      :character_id,
      :tracked
    ]

    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :uniq_map_character

      upsert_fields [
        :map_id,
        :character_id
      ]

      accept [
        :map_id,
        :character_id,
        :tracked
      ]

      argument :map_id, :uuid, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      change manage_relationship(:map_id, :map, on_lookup: :relate, on_no_match: nil)
      change manage_relationship(:character_id, :character, on_lookup: :relate, on_no_match: nil)
    end

    read :by_map_filtered do
      argument(:map_id, :string, allow_nil?: false)
      argument(:character_ids, {:array, :uuid}, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id) and character_id in ^arg(:character_ids)))
    end

    read :tracked_by_map_filtered do
      argument(:map_id, :string, allow_nil?: false)
      argument(:character_ids, {:array, :uuid}, allow_nil?: false)

      filter(
        expr(map_id == ^arg(:map_id) and tracked == true and character_id in ^arg(:character_ids))
      )
    end

    read :read_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :read_by_map_and_character do
      get? true

      argument(:map_id, :string, allow_nil?: false)
      argument(:character_id, :uuid, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id) and character_id == ^arg(:character_id)))
    end

    read :tracked_by_map_all do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id) and tracked == true))
    end

    read :tracked_by_character do
      argument(:character_id, :uuid, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id) and tracked == true))
    end

    update :update do
      primary? true
      require_atomic? false

      accept([
        :ship,
        :ship_name,
        :ship_item_id,
        :solar_system_id,
        :structure_id,
        :station_id
      ])
    end

    update :track do
      accept [:map_id, :character_id]
      argument :map_id, :string, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      # Load the record first
      load do
        filter expr(map_id == ^arg(:map_id) and character_id == ^arg(:character_id))
      end

      # Only update the tracked field
      change set_attribute(:tracked, true)
    end

    update :untrack do
      accept [:map_id, :character_id]
      argument :map_id, :string, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      # Load the record first
      load do
        filter expr(map_id == ^arg(:map_id) and character_id == ^arg(:character_id))
      end

      # Only update the tracked field
      change set_attribute(:tracked, false)
    end

    update :follow do
      accept [:map_id, :character_id]
      argument :map_id, :string, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      # Load the record first
      load do
        filter expr(map_id == ^arg(:map_id) and character_id == ^arg(:character_id))
      end

      # Only update the followed field
      change set_attribute(:followed, true)
    end

    update :unfollow do
      accept [:map_id, :character_id]
      argument :map_id, :string, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      # Load the record first
      load do
        filter expr(map_id == ^arg(:map_id) and character_id == ^arg(:character_id))
      end

      # Only update the followed field
      change set_attribute(:followed, false)
    end
  end

  cloak do
    vault(WandererApp.Vault)

    attributes([
      :ship,
      :ship_name,
      :ship_item_id,
      :solar_system_id,
      :structure_id,
      :station_id
    ])

    decrypt_by_default([
      :ship,
      :ship_name,
      :ship_item_id,
      :solar_system_id,
      :structure_id,
      :station_id
    ])
  end

  attributes do
    uuid_primary_key :id

    attribute :tracked, :boolean do
      default false
      allow_nil? true
    end

    attribute :followed, :boolean do
      default false
      allow_nil? true
    end

    attribute :solar_system_id, :integer
    attribute :structure_id, :integer
    attribute :station_id, :integer
    attribute :ship, :integer
    attribute :ship_name, :string
    attribute :ship_item_id, :integer

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map, primary_key?: true, allow_nil?: false, public?: true

    belongs_to :character, WandererApp.Api.Character,
      primary_key?: true,
      allow_nil?: false,
      public?: true
  end

  identities do
    identity :uniq_map_character, [:map_id, :character_id]
  end
end
