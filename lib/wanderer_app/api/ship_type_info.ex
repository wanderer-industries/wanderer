defmodule WandererApp.Api.ShipTypeInfo do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("ship_type_infos_v1")
  end

  json_api do
    type "ship_type_info"

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

    define(:by_type_id,
      get_by: [:type_id],
      action: :read
    )

    define(:find_by_name, action: :find_by_name)
  end

  actions do
    default_accept [
      :type_id,
      :group_id,
      :group_name,
      :name,
      :description,
      :mass,
      :capacity,
      :volume
    ]

    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      upsert? true
      upsert_identity :type_id

      upsert_fields [
        :group_id,
        :group_name,
        :name,
        :description,
        :mass,
        :capacity,
        :volume
      ]
    end

    read :find_by_name do
      argument(:name, :string, allow_nil?: false)

      filter(expr(contains(name, string_downcase(^arg(:name)))))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type_id, :integer
    attribute :group_id, :integer
    attribute :group_name, :string
    attribute :name, :string
    attribute :description, :string
    attribute :mass, :string
    attribute :capacity, :string
    attribute :volume, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :type_id, [:type_id] do
      pre_check?(true)
    end
  end
end
