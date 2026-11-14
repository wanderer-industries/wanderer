defmodule WandererApp.Repo.Migrations.AddMapConnectionLockedByFk do
  @moduledoc """
  Adds the missing foreign key on `map_chain_v1.locked_by_id`.

  20260425000000 added the column as a bare `:binary_id` with no constraint,
  while `MapConnection` declares `belongs_to :locked_by, Character`. The
  resource therefore promised a relationship the database never enforced, and
  because no snapshot was regenerated at the time, every subsequent
  `mix ash_postgres.generate_migrations` run wanted to re-add both
  `locked_by_id` and `locked_at` from scratch.

  This migration adds only the constraint -- the columns already exist -- and
  regenerates the snapshot so codegen stops proposing that duplicate.
  """

  use Ecto.Migration

  def up do
    # Character has a plain :destroy action and the column has never been
    # constrained, so rows may point at characters that no longer exist.
    # Those would abort the ALTER below, so release their locks first: a lock
    # held by a deleted character is already meaningless.
    execute("""
    UPDATE map_chain_v1
       SET locked_by_id = NULL
     WHERE locked_by_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM character_v1 WHERE character_v1.id = map_chain_v1.locked_by_id)
    """)

    alter table(:map_chain_v1) do
      modify :locked_by_id,
             references(:character_v1,
               column: :id,
               name: "map_chain_v1_locked_by_id_fkey",
               type: :uuid,
               on_delete: :nilify_all
             )
    end
  end

  # Deliberately not a mirror image of up/0. The columns predate this
  # migration, so dropping them on rollback would destroy data this migration
  # never created; only the constraint comes off. Locks released from deleted
  # characters stay released -- there is nothing valid to restore them to.
  def down do
    drop_if_exists constraint(:map_chain_v1, "map_chain_v1_locked_by_id_fkey")
  end
end
