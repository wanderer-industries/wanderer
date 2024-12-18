defmodule WandererApp.Repo.Migrations.AddMapState do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:map_state_v1, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :systems_last_activity, :binary, default: nil
      add :connections_eol_time, :binary, default: nil

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :map_id,
          references(:maps_v1,
            column: :id,
            name: "map_state_v1_map_id_fkey",
            type: :uuid,
            prefix: "public"
          )
    end

    create unique_index(:map_state_v1, [:map_id], name: "map_state_v1_uniq_map_id_index")
  end

  def down do
    drop_if_exists unique_index(:map_state_v1, [:map_id], name: "map_state_v1_uniq_map_id_index")

    drop constraint(:map_state_v1, "map_state_v1_map_id_fkey")

    drop table(:map_state_v1)
  end
end
