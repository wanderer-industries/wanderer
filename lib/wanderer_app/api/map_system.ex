defmodule WandererApp.Api.MapSystem do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_system_v1")
  end

  json_api do
    type "map_systems"

    includes([:map])

    default_fields([
      :name,
      :solar_system_id,
      :status,
      :custom_name,
      :description,
      :tag,
      :temporary_name,
      :labels
    ])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_systems")
      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_solar_system_id,
      get_by: [:solar_system_id],
      action: :read
    )

    define(:by_map_id_and_solar_system_id,
      get_by: [:map_id, :solar_system_id],
      action: :read
    )

    define(:read_all_by_map,
      action: :read_all_by_map
    )

    define(:read_visible_by_map,
      action: :read_visible_by_map
    )

    define(:read_by_map_and_solar_system,
      action: :read_by_map_and_solar_system
    )

    define(:update_name, action: :update_name)
    define(:update_description, action: :update_description)
    define(:update_locked, action: :update_locked)
    define(:update_status, action: :update_status)
    define(:update_tag, action: :update_tag)
    define(:update_temporary_name, action: :update_temporary_name)
    define(:update_labels, action: :update_labels)
    define(:update_linked_sig_eve_id, action: :update_linked_sig_eve_id)
    define(:update_position, action: :update_position)
    define(:update_visible, action: :update_visible)
  end

  actions do
    default_accept [
      :map_id,
      :name,
      :solar_system_id,
      :position_x,
      :position_y,
      :status,
      :visible,
      :locked,
      :custom_name,
      :description,
      :tag,
      :temporary_name,
      :labels,
      :added_at,
      :linked_sig_eve_id
    ]

    defaults [:create, :update, :destroy]

    read :read do
      primary?(true)

      pagination offset?: true,
                 default_limit: 100,
                 max_page_size: 500,
                 countable: true,
                 required?: false
    end

    read :read_all_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :read_visible_by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id) and visible == true))
    end

    read :read_by_map_and_solar_system do
      argument(:map_id, :string, allow_nil?: false)
      argument(:solar_system_id, :integer, allow_nil?: false)

      get?(true)

      filter(expr(map_id == ^arg(:map_id) and solar_system_id == ^arg(:solar_system_id)))
    end

    update :update_name do
      accept [:name]
    end

    update :update_description do
      accept [:description]
    end

    update :update_locked do
      accept [:locked]
    end

    update :update_status do
      accept [:status]
    end

    update :update_tag do
      accept [:tag]
    end

    update :update_temporary_name do
      accept [:temporary_name]
    end

    update :update_labels do
      accept [:labels]
    end

    update :update_position do
      accept [:position_x, :position_y]

      change(set_attribute(:visible, true))
    end

    update :update_linked_sig_eve_id do
      accept [:linked_sig_eve_id]
    end

    update :update_visible do
      accept [:visible]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :solar_system_id, :integer do
      allow_nil? false
    end

    # by default it will default solar system name
    attribute :name, :string do
      allow_nil? false
    end

    attribute :custom_name, :string do
      allow_nil? true
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :tag, :string do
      allow_nil? true
    end

    attribute :temporary_name, :string do
      allow_nil? true
    end

    attribute :labels, :string do
      allow_nil? true
    end

    # unknown: 0
    # friendly: 1
    # warning: 2
    # targetPrimary: 3
    # targetSecondary: 4
    # dangerousPrimary: 5
    # dangerousSecondary: 6
    # lookingFor: 7
    # home: 8
    attribute :status, :integer do
      default 0

      allow_nil? true
    end

    attribute :visible, :boolean do
      default true
      allow_nil? true
    end

    attribute :locked, :boolean do
      default false
      allow_nil? true
    end

    attribute :position_x, :integer do
      default 0
      allow_nil? true
    end

    attribute :position_y, :integer do
      default 0
      allow_nil? true
    end

    attribute :added_at, :utc_datetime do
      allow_nil? true
    end

    attribute :linked_sig_eve_id, :string do
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

  identities do
    identity(:map_solar_system_id, [:map_id, :solar_system_id])
  end
end
