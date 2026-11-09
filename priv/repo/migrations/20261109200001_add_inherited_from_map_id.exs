defmodule WandererApp.Repo.Migrations.AddInheritedFromMapId do
  @moduledoc """
  Adds inherited_from_map_id to comments and structures tables.
  Tracks which records were copied from a source map during intel sync.
  Records with this field set are read-only on the subscriber map.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    repo().query!(
      "ALTER TABLE map_system_comments_v1 ADD COLUMN IF NOT EXISTS inherited_from_map_id uuid REFERENCES maps_v1(id) ON DELETE CASCADE",
      []
    )

    repo().query!(
      "ALTER TABLE map_system_structures_v1 ADD COLUMN IF NOT EXISTS inherited_from_map_id uuid REFERENCES maps_v1(id) ON DELETE CASCADE",
      []
    )

    create_if_not_exists index(:map_system_comments_v1, [:inherited_from_map_id],
                           concurrently: true
                         )

    create_if_not_exists index(:map_system_structures_v1, [:inherited_from_map_id],
                           concurrently: true
                         )
  end

  def down do
    drop_if_exists index(:map_system_comments_v1, [:inherited_from_map_id], concurrently: true)
    drop_if_exists index(:map_system_structures_v1, [:inherited_from_map_id], concurrently: true)

    alter table(:map_system_comments_v1) do
      remove :inherited_from_map_id
    end

    alter table(:map_system_structures_v1) do
      remove :inherited_from_map_id
    end
  end
end
