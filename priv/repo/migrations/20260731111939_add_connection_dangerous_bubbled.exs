defmodule WandererApp.Repo.Migrations.AddConnectionDangerousBubbled do
  @moduledoc """
  Adds the manually set connection flags: whether the connection is dangerous and which of its
  ends are bubbled.

  The generated version also re-added locked_at and locked_by_id, which are already on the table -
  the resource snapshots are behind the database for those columns.
  """

  use Ecto.Migration

  def up do
    alter table(:map_chain_v1) do
      add :dangerous, :boolean, null: false, default: false
      add :bubbled, :bigint, null: false, default: 0
    end
  end

  def down do
    alter table(:map_chain_v1) do
      remove :bubbled
      remove :dangerous
    end
  end
end
