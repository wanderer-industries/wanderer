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

    define(:update_settings, action: :update_settings)

    define(:update_hubs, action: :update_hubs)
  end

  actions do
    default_accept [
      :map_id,
      :user_id,
      :settings
    ]

    defaults [:create, :read, :update, :destroy]

    update :update_settings do
      accept [:settings]
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
