defmodule WandererApp.Repo.Migrations.MakeUserIdNullableInUserActivity do
  @moduledoc """
  Make user_id nullable in user_activity_v1 table to support security events
  where no user is authenticated (e.g., authentication failures).
  """

  use Ecto.Migration

  def up do
    # First, drop the primary key constraint since user_id is part of it
    execute "ALTER TABLE user_activity_v1 DROP CONSTRAINT user_activity_v1_pkey"

    # Modify user_id to be nullable
    alter table(:user_activity_v1) do
      modify :user_id, :uuid, null: true
    end

    # Recreate primary key with only id column
    execute "ALTER TABLE user_activity_v1 ADD PRIMARY KEY (id)"
  end

  def down do
    # Drop the single-column primary key
    execute "ALTER TABLE user_activity_v1 DROP CONSTRAINT user_activity_v1_pkey"

    # Make user_id not null again
    alter table(:user_activity_v1) do
      modify :user_id, :uuid, null: false
    end

    # Recreate the composite primary key
    execute "ALTER TABLE user_activity_v1 ADD PRIMARY KEY (id, user_id)"
  end
end
