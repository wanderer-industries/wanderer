defmodule WandererApp.Api.MapUserSettings do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_user_settings_v1")
  end

  code_interface do
    define(:create, action: :create)

    define(:by_user_id,
      get_by: [:map_id, :user_id],
      action: :read
    )

    define(:read_by_map, action: :read_by_map)
    
    define(:update_settings, action: :update_settings)
    define(:update_main_character, action: :update_main_character)
    define(:update_following_character, action: :update_following_character)
    define(:update_ready_characters, action: :update_ready_characters)

    define(:update_hubs, action: :update_hubs)
  end

  actions do
    default_accept [
      :map_id,
      :user_id,
      :settings
    ]

    defaults [:create, :read, :update, :destroy]

    read :read_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    update :update_settings do
      accept [:settings]
    end

    update :update_main_character do
      accept [:main_character_eve_id]
    end

    update :update_following_character do
      accept [:following_character_eve_id]
    end

    update :update_ready_characters do
      accept [:ready_characters]
    end

    update :update_hubs do
      accept [:hubs]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :settings, :string do
      allow_nil? true
    end

    attribute :main_character_eve_id, :string do
      allow_nil? true
    end

    attribute :following_character_eve_id, :string do
      allow_nil? true
    end

    attribute :ready_characters, {:array, :string} do
      allow_nil? true
      default([])
    end

    attribute :hubs, {:array, :string} do
      allow_nil?(true)

      default([])
    end
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map, primary_key?: true, allow_nil?: false
    belongs_to :user, WandererApp.Api.User, primary_key?: true, allow_nil?: false
  end

  identities do
    identity :uniq_map_user, [:map_id, :user_id]
  end
end
