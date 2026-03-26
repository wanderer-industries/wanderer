defmodule WandererApp.Repo.Migrations.AddPluginConfigCascadeDelete do
  @moduledoc """
  Adds cascade delete to map_plugin_configs_v1 foreign key so plugin configs
  are automatically cleaned up when a map is hard-deleted.
  """

  use Ecto.Migration

  def up do
    drop constraint(:map_plugin_configs_v1, "map_plugin_configs_v1_map_id_fkey")

    alter table(:map_plugin_configs_v1) do
      modify :map_id,
             references(:maps_v1,
               column: :id,
               name: "map_plugin_configs_v1_map_id_fkey",
               type: :uuid,
               on_delete: :delete_all
             )
    end
  end

  def down do
    drop constraint(:map_plugin_configs_v1, "map_plugin_configs_v1_map_id_fkey")

    alter table(:map_plugin_configs_v1) do
      modify :map_id,
             references(:maps_v1,
               column: :id,
               name: "map_plugin_configs_v1_map_id_fkey",
               type: :uuid
             )
    end
  end
end
