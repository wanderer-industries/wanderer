defmodule WandererApp.Api.Character do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak, AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("character_v1")
  end

  json_api do
    type "characters"

    # Only expose safe, non-sensitive attributes
    includes([:user])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/characters")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define(:read, action: :read)
    define(:search_by_name, action: :search_by_name)
    define(:last_active, action: :last_active)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_eve_id,
      get_by: [:eve_id],
      action: :read
    )

    define(:active_by_user,
      action: :active_by_user
    )

    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_alliance, action: :update_alliance)
    define(:update_corporation, action: :update_corporation)
    define(:update_ship, action: :update_ship)
    define(:update_location, action: :update_location)
    define(:update_wallet_balance, action: :update_wallet_balance)
    define(:assign_user!, action: :assign)
  end

  actions do
    default_accept [
      :eve_id,
      :name,
      :access_token,
      :refresh_token,
      :expires_at,
      :scopes,
      :tracking_pool
    ]

    defaults [:read, :destroy]

    create :create do
      accept([
        :eve_id,
        :name,
        :user_id,
        :access_token,
        :refresh_token,
        :expires_at,
        :scopes,
        :tracking_pool,
        :corporation_id,
        :corporation_name,
        :corporation_ticker,
        :alliance_id,
        :alliance_name,
        :alliance_ticker,
        :solar_system_id,
        :structure_id,
        :station_id,
        :ship,
        :ship_name,
        :ship_item_id,
        :eve_wallet_balance,
        :location,
        :character_owner_hash,
        :token_type,
        :online
      ])
    end

    create :link do
      accept([:eve_id, :name, :user_id])
    end

    read :search_by_name do
      argument :name, :string, allow_nil?: true

      filter expr(contains(string_downcase(name), string_downcase(^arg(:name))))
    end

    read :active_by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id) and deleted == false))
    end

    read :available_by_map do
      argument(:map_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id) and deleted == false))
    end

    read :last_active do
      argument(:from, :utc_datetime, allow_nil?: false)

      filter(expr(updated_at > ^arg(:from)))
    end

    update :assign do
      accept []
      require_atomic? false

      argument :user_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:user_id, :user, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      accept([:name, :access_token, :refresh_token, :expires_at, :scopes, :tracking_pool])

      change(set_attribute(:deleted, false))
    end

    update :mark_as_deleted do
      accept([])

      change(atomic_update(:deleted, true))
      change(atomic_update(:user_id, nil))
    end

    update :update_online do
      accept([:online])
    end

    update :update_location do
      require_atomic? false

      accept([:solar_system_id, :structure_id, :station_id])
    end

    update :update_ship do
      require_atomic? false

      accept([:ship, :ship_name, :ship_item_id])
    end

    update :update_corporation do
      require_atomic? false

      accept([:corporation_id, :corporation_name, :corporation_ticker, :alliance_id])
    end

    update :update_alliance do
      require_atomic? false

      accept([:alliance_id, :alliance_name, :alliance_ticker])
    end

    update :update_wallet_balance do
      require_atomic? false

      accept([:eve_wallet_balance])
    end
  end

  cloak do
    vault(WandererApp.Vault)

    attributes([
      :eve_wallet_balance,
      :location,
      :ship,
      :solar_system_id,
      :structure_id,
      :station_id,
      :access_token,
      :refresh_token
    ])

    decrypt_by_default([
      :location,
      :ship,
      :solar_system_id,
      :structure_id,
      :station_id,
      :access_token,
      :refresh_token
    ])
  end

  attributes do
    uuid_primary_key :id

    attribute :eve_id, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :online, :boolean do
      default(false)
      allow_nil?(true)
    end

    attribute :deleted, :boolean do
      default(false)
      allow_nil?(true)
    end

    attribute :scopes, :string
    attribute :character_owner_hash, :string
    attribute :access_token, :string
    attribute :refresh_token, :string
    attribute :token_type, :string
    attribute :expires_at, :integer
    attribute :location, :string
    attribute :solar_system_id, :integer
    attribute :structure_id, :integer
    attribute :station_id, :integer
    attribute :ship, :integer
    attribute :ship_name, :string
    attribute :ship_item_id, :integer

    attribute :corporation_id, :integer do
      public? true
    end

    attribute :corporation_name, :string do
      public? true
    end

    attribute :corporation_ticker, :string do
      public? true
    end

    attribute :alliance_id, :integer do
      public? true
    end

    attribute :alliance_name, :string do
      public? true
    end

    attribute :alliance_ticker, :string do
      public? true
    end

    attribute :eve_wallet_balance, :float

    attribute :tracking_pool, :string do
      public? true
    end

    create_timestamp(:inserted_at) do
      public? true
    end

    update_timestamp(:updated_at) do
      public? true
    end
  end

  relationships do
    belongs_to :user, WandererApp.Api.User do
      attribute_writable? true
      public? true
    end
  end

  identities do
    identity :unique_eve_id, [:eve_id]
  end
end
