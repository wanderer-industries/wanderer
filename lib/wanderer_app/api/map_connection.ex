defmodule WandererApp.Api.MapConnection do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_chain_v1")
  end

  code_interface do
    define(:create, action: :create)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_locations,
      get_by: [:map_id, :solar_system_source, :solar_system_target],
      action: :read
    )

    define(:read_by_map, action: :read_by_map)
    define(:get_link_pairs_advanced, action: :get_link_pairs_advanced)
    define(:destroy, action: :destroy)

    define(:update_mass_status, action: :update_mass_status)
    define(:update_time_status, action: :update_time_status)
    define(:update_ship_size_type, action: :update_ship_size_type)
    define(:update_locked, action: :update_locked)
  end

  actions do
    default_accept [
      :map_id,
      :solar_system_source,
      :solar_system_target
    ]

    defaults [:create, :read, :update, :destroy]

    read :read_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
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

    # where 0 - normal
    # where 1 - end of life
    attribute :time_status, :integer do
      default(0)

      allow_nil?(true)
    end

    # where 0 - Frigate
    # where 1 - Medium and Large
    # where 2 - Capital
    attribute :ship_size_type, :integer do
      default(1)

      allow_nil?(true)
    end

    attribute :wormhole_type, :string

    attribute :count_of_passage, :integer do
      default(0)

      allow_nil?(true)
    end

    attribute :locked, :boolean

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end
  end
end
