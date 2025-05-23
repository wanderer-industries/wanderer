defmodule WandererApp.Repo.Migrations.AddMapUserSettingsHubs do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:map_user_settings_v1) do
      add :hubs, {:array, :text}, default: []
    end
  end

  def down do
    alter table(:map_user_settings_v1) do
      remove :hubs
    end
  end
end
