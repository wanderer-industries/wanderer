defmodule WandererApp.Api.MapSolarSystemJumps do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_solar_system_jumps_v1")
  end

  code_interface do
    define(:read,
      action: :read
    )

    define(:find, action: :find)
  end

  actions do
    default_accept [
      :from_solar_system_id,
      :to_solar_system_id
    ]

    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      upsert? true
      upsert_identity :solar_system_from_to

      upsert_fields [
        :from_solar_system_id,
        :to_solar_system_id
      ]
    end

    read :find do
      argument(:before_system_id, :integer, allow_nil?: false)
      argument(:current_system_id, :integer, allow_nil?: false)

      filter(
        expr(
          (from_solar_system_id == ^arg(:before_system_id) and
             to_solar_system_id == ^arg(:current_system_id)) or
            (to_solar_system_id == ^arg(:before_system_id) and
               from_solar_system_id == ^arg(:current_system_id))
        )
      )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :from_solar_system_id, :integer
    attribute :to_solar_system_id, :integer

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :solar_system_from_to, [:from_solar_system_id, :to_solar_system_id] do
      pre_check?(true)
    end
  end
end
