defmodule WandererApp.Api.MapSystemComment do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_system_comments_v1")
  end

  # /api/v1 exposes comments read-only (get, index, index by_system_id), so
  # only :read is scoped. Create/destroy exist as code interfaces for internal
  # callers, which reach them as trusted actors via the bypass.
  policies do
    bypass WandererApp.Api.Policies.MapScoped.trusted() do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if WandererApp.Api.Policies.MapScoped.in_token_map([:system, :map_id])
    end
  end

  json_api do
    type "map_system_comments"

    includes([
      :system,
      :character
    ])

    default_fields([
      :text
    ])

    routes do
      base("/map_system_comments")

      get(:read)
      index :read

      # Custom route for system-specific comments
      index :by_system_id, route: "/by_system/:system_id"
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_system_id, action: :by_system_id, args: [:system_id])
  end

  actions do
    default_accept [
      :system_id,
      :character_id,
      :text
    ]

    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :system_id,
        :character_id,
        :text
      ]
    end

    read :by_system_id do
      argument(:system_id, :string, allow_nil?: false)

      filter(expr(system_id == ^arg(:system_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :text, :string do
      allow_nil? false
      public? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
      public? true
    end

    belongs_to :character, WandererApp.Api.Character do
      attribute_writable? true
      public? true
    end
  end
end
