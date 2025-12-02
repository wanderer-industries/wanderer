defmodule WandererApp.Api.MapUserSettings do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_user_settings_v1")
  end

  json_api do
    type "map_user_settings"

    # Handle composite primary key
    primary_key do
      keys([:map_id, :user_id])
    end

    includes([
      :map,
      :user
    ])

    default_fields([
      :settings,
      :main_character_eve_id,
      :following_character_eve_id,
      :hubs
    ])

    routes do
      base("/map_user_settings")

      get(:read)
      index :read
    end
  end

  code_interface do
    define(:create, action: :create)

    define(:by_user_id,
      get_by: [:map_id, :user_id],
      action: :read
    )

    define(:update_hubs, action: :update_hubs)
    define(:update_settings, action: :update_settings)
    define(:update_following_character, action: :update_following_character)
    define(:update_main_character, action: :update_main_character)
  end

  actions do
    default_accept [
      :map_id,
      :user_id,
      :settings
    ]

    defaults [:create, :read, :destroy]

    update :update do
      require_atomic? false
    end

    update :update_settings do
      accept [:settings]
      require_atomic? false
    end

    update :update_main_character do
      accept [:main_character_eve_id]
      require_atomic? false
    end

    update :update_following_character do
      accept [:following_character_eve_id]
      require_atomic? false
    end

    update :update_hubs do
      accept [:hubs]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :settings, :string do
      allow_nil? true
      public? true
    end

    attribute :main_character_eve_id, :string do
      allow_nil? true
      public? true
    end

    attribute :following_character_eve_id, :string do
      allow_nil? true
      public? true
    end

    attribute :hubs, {:array, :string} do
      allow_nil?(true)
      public? true
      default([])
    end
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map, primary_key?: true, allow_nil?: false, public?: true
    belongs_to :user, WandererApp.Api.User, primary_key?: true, allow_nil?: false, public?: true
  end

  identities do
    identity :uniq_map_user, [:map_id, :user_id]
  end
end
