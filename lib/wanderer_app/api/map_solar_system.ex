defmodule WandererApp.Api.MapSolarSystem do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_solar_system_v2")
  end

  json_api do
    type "map_solar_systems"

    # Enable automatic filtering and sorting
    derive_filter?(true)
    derive_sort?(true)

    routes do
      # No routes - this resource should not be exposed via API
    end
  end

  code_interface do
    define(:read,
      action: :read
    )

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_solar_system_id,
      get_by: [:solar_system_id],
      action: :read
    )

    define(:find_by_name, action: :find_by_name)
    define(:get_wh_class_a, action: :get_wh_class_a)
    define(:get_trig_systems, action: :get_trig_systems)
  end

  actions do
    default_accept [
      :solar_system_id,
      :region_id,
      :constellation_id,
      :solar_system_name,
      :solar_system_name_lc,
      :constellation_name,
      :region_name,
      :system_class,
      :security,
      :type_description,
      :class_title,
      :is_shattered,
      :effect_name,
      :effect_power,
      :statics,
      :wandering,
      :triglavian_invasion_status,
      :sun_type_id
    ]

    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      upsert? true
      upsert_identity :solar_system_id

      upsert_fields [
        :region_id,
        :constellation_id,
        :solar_system_name,
        :solar_system_name_lc,
        :constellation_name,
        :region_name,
        :system_class,
        :security,
        :type_description,
        :class_title,
        :is_shattered,
        :effect_name,
        :effect_power,
        :statics,
        :wandering,
        :triglavian_invasion_status,
        :sun_type_id
      ]
    end

    read :find_by_name do
      argument(:name, :string, allow_nil?: false)

      filter(expr(contains(solar_system_name_lc, string_downcase(^arg(:name)))))
    end

    read :get_wh_class_a do
      filter(expr(system_class == 1))
    end

    read :get_trig_systems do
      filter(expr(triglavian_invasion_status != "Normal"))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :region_id, :integer
    attribute :constellation_id, :integer
    attribute :solar_system_id, :integer
    attribute :solar_system_name, :string
    attribute :solar_system_name_lc, :string
    attribute :constellation_name, :string
    attribute :region_name, :string
    attribute :system_class, :integer
    attribute :security, :string
    attribute :type_description, :string
    attribute :class_title, :string
    attribute :is_shattered, :boolean
    attribute :effect_name, :string
    attribute :effect_power, :integer

    attribute :statics, {:array, :string} do
      allow_nil?(true)

      default([])
    end

    attribute :wandering, {:array, :string} do
      allow_nil?(true)

      default([])
    end

    attribute :triglavian_invasion_status, :string
    attribute :sun_type_id, :integer

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :solar_system_id, [:solar_system_id] do
      pre_check?(true)
    end
  end
end
