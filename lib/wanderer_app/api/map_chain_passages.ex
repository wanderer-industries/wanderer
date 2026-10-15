defmodule WandererApp.Api.MapChainPassages do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  import Ecto.Query

  postgres do
    repo(WandererApp.Repo)
    table("map_chain_passages_v1")

    # Built concurrently: passages are inserted on every jump, so a plain
    # CREATE INDEX would block those inserts for the whole build.
    custom_indexes do
      # `by_connection` filters on map_id, source, target and a lower bound
      # on inserted_at. The character activity report filters on map_id and
      # inserted_at only, so it uses just the map_id prefix of this index.
      index [:map_id, :solar_system_source_id, :solar_system_target_id, :inserted_at],
        name: "map_chain_passages_v1_connection_index",
        concurrently: true

      # `WandererApp.Map.GarbageCollector.cleanup_chain_passages/0`
      # deletes by updated_at; the retention window is configurable,
      # so the table can grow well past the default week.
      index [:updated_at], name: "map_chain_passages_v1_updated_at_index", concurrently: true
    end
  end

  code_interface do
    define(:new, action: :new)
    define(:read, action: :read)
    define(:by_map_id, action: :by_map_id)
    define(:by_connection, action: :by_connection)
    define(:update_mass, action: :update_mass)
    define(:by_id, get_by: [:id], action: :read)
  end

  actions do
    default_accept [
      :ship_type_id,
      :ship_name,
      :mass,
      :solar_system_source_id,
      :solar_system_target_id
    ]

    defaults [:create, :read, :destroy]

    update :update do
      accept [:mass]
      require_atomic? false
    end

    update :update_mass do
      accept [:mass]
      require_atomic? false
    end

    create :new do
      accept [
        :ship_type_id,
        :ship_name,
        :mass,
        :solar_system_source_id,
        :solar_system_target_id,
        :map_id,
        :character_id
      ]

      primary?(true)
    end

    action :by_map_id, {:array, :struct} do
      argument(:map_id, :string, allow_nil?: false)

      run fn input, _context ->
        from(p in __MODULE__,
          join: c in assoc(p, :character),
          where:
            p.map_id == ^input.arguments.map_id and
              c.id == p.character_id,
          group_by: [c.id],
          select: [c, count()]
        )
        |> WandererApp.Repo.all()
        |> Enum.map(fn [character, count] -> %{character: character, count: count} end)
        |> Enum.sort_by(& &1.count, :desc)
        |> then(&{:ok, &1})
      end
    end

    action :by_connection, {:array, :struct} do
      argument(:map_id, :string, allow_nil?: false)
      argument(:from, :string, allow_nil?: false)
      argument(:to, :string, allow_nil?: false)
      argument(:after, :utc_datetime, allow_nil?: false)

      run fn input, _context ->
        from(p in __MODULE__,
          join: c in assoc(p, :character),
          where:
            p.map_id == ^input.arguments.map_id and
              c.id == p.character_id and
              p.solar_system_source_id == ^input.arguments.from and
              p.solar_system_target_id == ^input.arguments.to and
              p.inserted_at >= ^input.arguments.after,
          select: [p, c]
        )
        |> WandererApp.Repo.all()
        |> Enum.map(fn [passage, character] ->
          %{
            id: passage.id,
            ship_type_id: passage.ship_type_id,
            ship_name: passage.ship_name,
            mass: passage.mass,
            inserted_at: passage.inserted_at,
            character: character
          }
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> then(&{:ok, &1})
      end
    end
  end

  aggregates do
    count :jumps, :character do
      filter expr(not is_nil(character_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :ship_type_id, :integer
    attribute :ship_name, :string
    attribute :mass, :integer
    attribute :solar_system_source_id, :integer
    attribute :solar_system_target_id, :integer

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map,
      primary_key?: true,
      allow_nil?: false,
      attribute_writable?: true

    belongs_to :character, WandererApp.Api.Character,
      primary_key?: true,
      allow_nil?: false,
      attribute_writable?: true
  end
end
