defmodule WandererApp.Api.MapState do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_state_v1")
  end

  json_api do
    type "map_states"

    routes do
      # No routes - this resource should not be exposed via API
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    define(:get_last_active, action: :last_active, args: [:from])

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map_id,
      get_by: [:map_id],
      action: :read
    )
  end

  actions do
    default_accept [
      :map_id,
      :systems_last_activity,
      :connections_eol_time,
      :connections_start_time
    ]

    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :uniq_map_id

      upsert_fields [
        :systems_last_activity,
        :connections_eol_time,
        :connections_start_time,
        :updated_at
      ]
    end

    read :last_active do
      argument(:from, :utc_datetime, allow_nil?: false)

      filter(expr(updated_at > ^arg(:from)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :systems_last_activity, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
    end

    attribute :connections_start_time, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
    end

    attribute :connections_eol_time, WandererApp.Schema.AshErlangBinary do
      allow_nil?(true)
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
    identity(:uniq_map_id, [:map_id])
  end
end
