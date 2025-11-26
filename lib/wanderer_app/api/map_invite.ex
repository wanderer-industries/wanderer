defmodule WandererApp.Api.MapInvite do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_invites_v1")
  end

  code_interface do
    define(:new, action: :new)
    define(:read, action: :read)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map,
      action: :by_map
    )
  end

  actions do
    default_accept [
      :token
    ]

    defaults [:read, :update, :destroy]

    create :new do
      accept [
        :map_id,
        :token,
        :type,
        :valid_until
      ]

      primary?(true)

      argument :map_id, :uuid, allow_nil?: true

      change manage_relationship(:map_id, :map, on_lookup: :relate, on_no_match: nil)
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :token, :string do
      allow_nil? true
    end

    attribute :type, :atom do
      default "user"

      constraints(
        one_of: [
          :user,
          :admin
        ]
      )

      allow_nil?(false)
    end

    attribute :valid_until, :utc_datetime do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end
  end

  postgres do
    references do
      reference :map, on_delete: :delete
    end
  end
end
