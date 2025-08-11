defmodule WandererApp.Repo.Migrations.AddSecurityAuditIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Add indexes for security audit queries
    create_if_not_exists index(:user_activity_v1, [:entity_type, :event_type, :inserted_at],
                           concurrently: true
                         )

    create_if_not_exists index(:user_activity_v1, [:user_id, :inserted_at], concurrently: true)
    create_if_not_exists index(:user_activity_v1, [:event_type], concurrently: true)

    # Partial index for security events only - for better performance
    create_if_not_exists index(:user_activity_v1, [:user_id, :inserted_at],
                           where: "entity_type = 'security_event'",
                           name: :user_activity_v1_security_events_idx,
                           concurrently: true
                         )

    # Index for entity_id queries (used by Map.Audit)
    create_if_not_exists index(:user_activity_v1, [:entity_id, :inserted_at], concurrently: true)
  end

  def down do
    drop_if_exists index(:user_activity_v1, [:entity_id, :inserted_at], concurrently: true)

    drop_if_exists index(:user_activity_v1, [:user_id, :inserted_at],
                     name: :user_activity_v1_security_events_idx,
                     concurrently: true
                   )

    drop_if_exists index(:user_activity_v1, [:event_type], concurrently: true)
    drop_if_exists index(:user_activity_v1, [:user_id, :inserted_at], concurrently: true)

    drop_if_exists index(:user_activity_v1, [:entity_type, :event_type, :inserted_at],
                     concurrently: true
                   )
  end
end
