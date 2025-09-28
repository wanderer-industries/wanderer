defmodule WandererApp.Api.MapConnection do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_chain_v1")
  end

  json_api do
    type "map_connections"

    includes([:map])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_connections")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_locations, action: :read_by_locations)

    define(:read_by_map, action: :read_by_map)
    define(:get_link_pairs_advanced, action: :get_link_pairs_advanced)
    define(:destroy, action: :destroy)

    define(:update_mass_status, action: :update_mass_status)
    define(:update_time_status, action: :update_time_status)
    define(:update_ship_size_type, action: :update_ship_size_type)
    define(:update_locked, action: :update_locked)
    define(:update_custom_info, action: :update_custom_info)
    define(:update_type, action: :update_type)
    define(:update_wormhole_type, action: :update_wormhole_type)
  end

  actions do
    default_accept [
      :map_id,
      :solar_system_source,
      :solar_system_target,
      :type,
      :ship_size_type,
      :mass_status,
      :time_status,
      :wormhole_type,
      :count_of_passage,
      :locked,
      :custom_info
    ]

    defaults [:create, :read, :update, :destroy]

    read :read_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :read_by_locations do
      argument(:map_id, :string, allow_nil?: false)
      argument(:solar_system_source, :integer, allow_nil?: false)
      argument(:solar_system_target, :integer, allow_nil?: false)

      filter(
        expr(
          map_id == ^arg(:map_id) and solar_system_source == ^arg(:solar_system_source) and
            solar_system_target == ^arg(:solar_system_target)
        )
      )
    end

    read :get_link_pairs_advanced do
      argument(:map_id, :string, allow_nil?: false)
      argument(:include_mass_crit, :boolean, allow_nil?: false)
      argument(:include_eol, :boolean, allow_nil?: false)
      argument(:include_frig, :boolean, allow_nil?: false)

      filter(
        expr(
          map_id == ^arg(:map_id) and (^arg(:include_mass_crit) or mass_status != 2) and
            (^arg(:include_eol) or time_status != 1) and
            (^arg(:include_frig) or ship_size_type != 0)
        )
      )
    end

    update :update_mass_status do
      accept [:mass_status]
    end

    update :update_time_status do
      accept [:time_status]
    end

    update :update_ship_size_type do
      accept [:ship_size_type]
    end

    update :update_locked do
      accept [:locked]
    end

    update :update_custom_info do
      accept [:custom_info]
    end

    update :update_type do
      accept [:type]
    end

    update :update_wormhole_type do
      accept [:wormhole_type]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :solar_system_source, :integer
    attribute :solar_system_target, :integer

    # where 0 - greater than half
    # where 1 - less than half
    # where 2 - critical less than 10%
    attribute :mass_status, :integer do
      default(0)

      allow_nil?(true)
    end

    # 0 - normal (env settings)
    # 1 - EOL 1h
    # 2 - EOL 4h
    # 3 - EOL 4.5h
    # 4 - EOL 16h
    # 5 - EOL 24h
    # 6 - EOL 48h
    attribute :time_status, :integer do
      default(0)

      allow_nil?(true)
    end

    # where 0 - Frigate (small
    # where 1 - Medium
    # where 2 - Large
    # where 3 - Freight
    # where 4 - Capital
    attribute :ship_size_type, :integer do
      default(2)

      allow_nil?(true)
    end

    # where 0 - Wormhole
    # where 1 - Gate
    # where 2 - Bridge
    attribute :type, :integer do
      default(0)

      allow_nil?(true)
    end

    attribute :wormhole_type, :string

    attribute :count_of_passage, :integer do
      default(0)

      allow_nil?(true)
    end

    attribute :locked, :boolean

    attribute :custom_info, :string do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
      public? true
    end
  end
end
