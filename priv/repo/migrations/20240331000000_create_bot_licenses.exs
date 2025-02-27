defmodule WandererApp.Repo.Migrations.CreateBotLicenses do
  use Ecto.Migration

  def change do
    create table(:bot_licenses_v1, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :license_key, :string, null: false
      add :is_valid, :boolean, null: false, default: true
      add :expire_at, :utc_datetime, null: true
      add :map_id, references(:maps_v1, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:bot_licenses_v1, [:license_key])
    create index(:bot_licenses_v1, [:map_id])
  end
end
