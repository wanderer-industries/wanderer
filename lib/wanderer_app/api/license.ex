defmodule WandererApp.Api.License do
  @moduledoc """
  Schema for bot licenses.

  A license is associated with a map subscription and allows access to bot functionality.
  Licenses have a unique key, validity status, and expiration date.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("bot_licenses_v1")
  end

  code_interface do
    define(:create, action: :create)
    define(:by_id, get_by: [:id], action: :read)
    define(:by_key, get_by: [:license_key], action: :read)
    define(:by_map_id, action: :by_map_id)
    define(:update_valid, action: :update_valid)
    define(:update_expire_at, action: :update_expire_at)
    define(:update_key, action: :update_key)
    define(:destroy, action: :destroy)
  end

  actions do
    default_accept [
      :map_id,
      :license_key,
      :is_valid,
      :expire_at
    ]

    defaults [:create, :read, :update, :destroy]

    read :by_map_id do
      argument(:map_id, :uuid, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    update :update_valid do
      accept [:is_valid]
    end

    update :update_expire_at do
      accept [:expire_at]
    end

    update :update_key do
      accept [:license_key]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :license_key, :string do
      allow_nil? false
    end

    attribute :is_valid, :boolean do
      default true
      allow_nil? false
    end

    attribute :expire_at, :utc_datetime do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end
  end
end
