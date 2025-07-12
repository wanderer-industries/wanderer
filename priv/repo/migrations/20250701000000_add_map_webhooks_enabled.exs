defmodule WandererApp.Repo.Migrations.AddMapWebhooksEnabled do
  @moduledoc """
  Add webhooks_enabled field to maps table for per-map webhook control.
  """

  use Ecto.Migration

  def up do
    alter table(:maps_v1) do
      add :webhooks_enabled, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:maps_v1) do
      remove :webhooks_enabled
    end
  end
end
