defmodule WandererApp.Api.MapPing do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    primary_read_warning?: false

  postgres do
    repo(WandererApp.Repo)
    table("map_pings_v1")
  end

  code_interface do
    define(:new, action: :new)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map,
      action: :by_map
    )

    define(:by_map_and_system,
      action: :by_map_and_system
    )

    define(:by_inserted_before, action: :by_inserted_before, args: [:inserted_before])
  end

  actions do
    default_accept [
      :type,
      :message
    ]

    defaults [:destroy]

    update :update do
      require_atomic? false
    end

    read :read do
      primary? true

      # Security: Filter to only pings from actor's map
      prepare WandererApp.Api.Preparations.FilterPingsByActorMap
    end

    create :new do
      accept [
        :map_id,
        :system_id,
        :character_id,
        :type,
        :message
      ]

      primary?(true)
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id)))
    end

    read :by_map_and_system do
      argument(:map_id, :string, allow_nil?: false)
      argument(:system_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id) and system_id == ^arg(:system_id)))
    end

    read :by_inserted_before do
      argument(:inserted_before, :utc_datetime, allow_nil?: false)

      filter(expr(inserted_at <= ^arg(:inserted_before)))
    end

    # Admin action for cleanup - no actor filtering
    read :all_pings do
    end
  end

  attributes do
    uuid_primary_key :id

    # ping: 0
    # rally_point: 1
    attribute :type, :integer do
      default 0

      allow_nil? true
    end

    attribute :message, :string do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end

    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
    end

    belongs_to :character, WandererApp.Api.Character do
      attribute_writable? true
    end
  end

  postgres do
    references do
      reference :map, on_delete: :delete
      reference :system, on_delete: :delete
      reference :character, on_delete: :delete
    end
  end
end
