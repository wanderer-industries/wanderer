defmodule WandererApp.Api.MapTransaction do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("map_transactions_v1")
  end

  code_interface do
    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map, action: :by_map)
    define(:by_user, action: :by_user)
    define(:create, action: :create)
  end

  actions do
    default_accept [
      :map_id,
      :user_id,
      :type,
      :amount
    ]

    defaults [:create, :read, :update, :destroy]

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :by_user do
      prepare build(load: [:map])
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? true
    end

    attribute :type, :atom do
      default "in"

      constraints(
        one_of: [
          :in,
          :out
        ]
      )

      allow_nil?(true)
    end

    attribute :amount, :float do
      allow_nil? false
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
