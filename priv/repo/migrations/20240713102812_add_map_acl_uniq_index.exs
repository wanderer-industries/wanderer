defmodule WandererApp.Repo.Migrations.AddMapAclUniqIndex do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create unique_index(:map_access_lists_v1, [:map_id, :access_list_id],
             name: "map_access_lists_v1_unique_map_acl_index"
           )
  end

  def down do
    drop_if_exists unique_index(:map_access_lists_v1, [:map_id, :access_list_id],
                     name: "map_access_lists_v1_unique_map_acl_index"
                   )
  end
end
