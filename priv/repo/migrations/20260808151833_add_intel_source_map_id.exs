defmodule WandererApp.Repo.Migrations.AddIntelSourceMapId do
  @moduledoc """
  Adds intel_source_map_id to maps_v1 for cross-map intel sharing.
  A self-referencing FK that designates which map provides intel to this map.
  """
  use Ecto.Migration

  def up do
    alter table(:maps_v1) do
      add :intel_source_map_id,
          references(:maps_v1,
            column: :id,
            name: "maps_v1_intel_source_map_id_fkey",
            type: :uuid,
            on_delete: :nilify_all
          ),
          null: true
    end

    create index(:maps_v1, [:intel_source_map_id])
  end

  def down do
    drop_if_exists index(:maps_v1, [:intel_source_map_id])

    alter table(:maps_v1) do
      remove :intel_source_map_id
    end
  end
end
