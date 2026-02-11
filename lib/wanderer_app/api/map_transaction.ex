defmodule WandererApp.Api.MapTransaction do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  import Ecto.Query

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
    define(:top_donators, action: :top_donators)
  end

  actions do
    default_accept [
      :map_id,
      :user_id,
      :type,
      :amount
    ]

    defaults [:create, :read, :destroy]

    update :update do
      require_atomic? false
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end

    read :by_user do
      prepare build(load: [:map])
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end

    action :top_donators, {:array, :struct} do
      argument(:map_id, :string, allow_nil?: false)
      argument(:after, :utc_datetime, allow_nil?: true)

      run fn input, _context ->
        base =
          from(t in __MODULE__,
            where:
              t.map_id == ^input.arguments.map_id and
                t.type == :in and
                not is_nil(t.user_id),
            group_by: [t.user_id],
            select: %{user_id: t.user_id, total_amount: sum(t.amount)},
            order_by: [desc: sum(t.amount)],
            limit: 10
          )

        query =
          case input.arguments[:after] do
            nil -> base
            after_date -> base |> where([t], t.inserted_at >= ^after_date)
          end

        query
        |> WandererApp.Repo.all()
        |> then(&{:ok, &1})
      end
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
