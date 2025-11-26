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
    table("map_licenses_v1")
  end

  code_interface do
    define(:create, action: :create)
    define(:by_id, get_by: [:id], action: :read)
    define(:by_key, get_by: [:license_key], action: :read)
    define(:by_map_id, action: :by_map_id)
    define(:invalidate, action: :invalidate)
    define(:set_valid, action: :set_valid)
    define(:update_expire_at, action: :update_expire_at)
    define(:update_key, action: :update_key)
    define(:destroy, action: :destroy)
  end

  actions do
    default_accept [
      :lm_id,
      :map_id,
      :license_key,
      :is_valid,
      :expire_at
    ]

    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :uniq_map_id

      upsert_fields [
        :lm_id,
        :is_valid,
        :license_key,
        :expire_at
      ]
    end

    read :by_map_id do
      argument(:map_id, :uuid, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    update :invalidate do
      accept([])

      change(set_attribute(:is_valid, false))
    end

    update :set_valid do
      accept([])

      change(set_attribute(:is_valid, true))
    end

    update :update_expire_at do
      accept [:expire_at]
      require_atomic? false
    end

    update :update_key do
      accept [:license_key]
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :lm_id, :string do
      allow_nil? false
    end

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

  identities do
    identity :uniq_map_id, [:map_id] do
      pre_check?(true)
    end
  end
end
