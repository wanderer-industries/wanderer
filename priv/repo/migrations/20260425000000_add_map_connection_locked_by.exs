defmodule WandererApp.Repo.Migrations.AddMapConnectionLockedBy do
  @moduledoc """
  Add locked_by and locked_at tracking to map_chain_v1 connections
  """

  use Ecto.Migration

  def up do
    alter table(:map_chain_v1) do
      add :locked_by_id, :binary_id
      add :locked_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:map_chain_v1) do
      remove :locked_by_id
      remove :locked_at
    end
  end
end
