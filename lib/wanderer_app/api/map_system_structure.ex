defmodule WandererApp.Api.MapSystemStructure do
  @moduledoc """
  Ash resource representing a structure in a given map system.

  """

  @derive {Jason.Encoder,
           only: [
             :id,
             :system_id,
             :solar_system_id,
             :solar_system_name,
             :structure_type_id,
             :structure_type,
             :character_eve_id,
             :name,
             :notes,
             :owner_name,
             :owner_ticker,
             :owner_id,
             :status,
             :end_time,
             :inserted_at,
             :updated_at
           ]}

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_system_structures_v1")
  end

  json_api do
    type "map_system_structures"

    includes([
      :system
    ])

    # Enable automatic filtering and sorting
    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_system_structures")

      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)

      # Custom routes for specific queries
      index :all_active, route: "/active"
      index :by_system_id, route: "/by_system/:system_id"
    end
  end

  code_interface do
    define(:all_active, action: :all_active)
    define(:create, action: :create)
    define(:update, action: :update)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_system_id,
      action: :by_system_id,
      args: [:system_id]
    )
  end

  actions do
    default_accept [
      :system_id,
      :solar_system_name,
      :solar_system_id,
      :structure_type_id,
      :structure_type,
      :character_eve_id,
      :name,
      :notes,
      :owner_name,
      :owner_ticker,
      :owner_id,
      :status,
      :end_time
    ]

    defaults [:read, :destroy]

    read :all_active do
      prepare build(sort: [updated_at: :desc])
    end

    read :by_system_id do
      argument :system_id, :string, allow_nil?: false
      filter(expr(system_id == ^arg(:system_id)))
    end

    create :create do
      primary? true

      accept [
        :system_id,
        :solar_system_name,
        :solar_system_id,
        :structure_type_id,
        :structure_type,
        :character_eve_id,
        :name,
        :notes,
        :owner_name,
        :owner_ticker,
        :owner_id,
        :status,
        :end_time
      ]

      argument :system_id, :uuid, allow_nil?: false

      change manage_relationship(:system_id, :system,
               on_lookup: :relate,
               on_no_match: nil
             )
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :system_id,
        :solar_system_name,
        :solar_system_id,
        :structure_type_id,
        :structure_type,
        :character_eve_id,
        :name,
        :notes,
        :owner_name,
        :owner_ticker,
        :owner_id,
        :status,
        :end_time
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :structure_type_id, :string do
      allow_nil? false
    end

    attribute :structure_type, :string do
      allow_nil? false
    end

    attribute :character_eve_id, :string do
      allow_nil? false
    end

    attribute :solar_system_name, :string do
      allow_nil? false
    end

    attribute :solar_system_id, :integer do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :notes, :string do
      allow_nil? true
    end

    attribute :owner_name, :string do
      allow_nil? true
    end

    attribute :owner_ticker, :string do
      allow_nil? true
    end

    attribute :owner_id, :string do
      allow_nil? true
    end

    attribute :status, :string do
      allow_nil? true
    end

    attribute :end_time, :utc_datetime_usec do
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
      public? true
    end
  end
end
