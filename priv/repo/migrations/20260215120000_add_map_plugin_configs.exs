defmodule WandererApp.Repo.Migrations.AddMapPluginConfigs do
  @moduledoc """
  Creates the map_plugin_configs_v1 table for storing per-map plugin configuration.
  """

  use Ecto.Migration

  def up do
    create table(:map_plugin_configs_v1, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :map_id,
          references(:maps_v1,
            column: :id,
            name: "map_plugin_configs_v1_map_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :plugin_name, :text, null: false
      add :enabled, :boolean, null: false, default: false
      add :encrypted_config, :binary
      add :config_version, :bigint, null: false, default: 1

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:map_plugin_configs_v1, [:map_id, :plugin_name],
             name: "map_plugin_configs_v1_unique_map_plugin_index"
           )
  end

  def down do
    drop_if_exists unique_index(:map_plugin_configs_v1, [:map_id, :plugin_name],
                     name: "map_plugin_configs_v1_unique_map_plugin_index"
                   )

    drop constraint(:map_plugin_configs_v1, "map_plugin_configs_v1_map_id_fkey")

    drop table(:map_plugin_configs_v1)
  end
end
