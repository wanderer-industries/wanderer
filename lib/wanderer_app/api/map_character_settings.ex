defmodule WandererApp.Api.MapCharacterSettings do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_character_settings_v1")
  end

  code_interface do
    define(:create, action: :create)

    define(:read_by_map,
      action: :read_by_map
    )

    define(:tracked_by_map,
      action: :tracked_by_map
    )

    define(:tracked_by_map_all,
      action: :read_tracked_by_map
    )

    define(:track, action: :track)
    define(:untrack, action: :untrack)
  end

  actions do
    default_accept [
      :map_id,
      :character_id,
      :tracked
    ]

    defaults [:create, :read, :update, :destroy]

    read :tracked_by_map do
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

    read :read_tracked_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id) and tracked == true))
    end

    update :track do
      change(set_attribute(:tracked, true))
    end

    update :untrack do
      change(set_attribute(:tracked, false))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tracked, :boolean do
      default false
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map, primary_key?: true, allow_nil?: false
    belongs_to :character, WandererApp.Api.Character, primary_key?: true, allow_nil?: false
  end

  identities do
    identity :uniq_map_character, [:map_id, :character_id]
  end
end
