defmodule WandererApp.Repo.Migrations.AddPublicApiKeyUniqueIndex do
  @moduledoc """
  Adds a unique index on the public_api_key column of maps_v1.

  This migration:
  1. Creates a backup table (maps_v1_api_key_backup) for data safety
  2. Backs up and clears duplicate API keys (keeping the oldest by inserted_at)
  3. Creates a unique index on public_api_key where the value is not null
  4. Allows multiple NULL values (maps without API keys)
  5. Ensures all non-NULL API keys are unique

  The partial index (WHERE public_api_key IS NOT NULL) is used because:
  - Most maps won't have an API key set
  - We only care about uniqueness for maps that do have one
  - PostgreSQL's unique constraints on nullable columns already allow multiple NULLs,
    but a partial index is more explicit and efficient

  ## Data Recovery

  If you need to restore cleared API keys, query the backup table:

      SELECT map_id, old_public_api_key, backed_up_at
      FROM maps_v1_api_key_backup
      WHERE reason = 'duplicate_api_key_cleared_for_unique_index';

  To restore a specific map's API key:

      UPDATE maps_v1 SET public_api_key = '<old_key>'
      WHERE id = '<map_id>';

  Note: Restoring will cause uniqueness conflicts if duplicates still exist.
  """
  use Ecto.Migration

  def up do
    # Create backup table before any destructive changes
    create_backup_table()

    # Check for any duplicate non-null API keys and handle them (with backup)
    check_and_fix_duplicates()

    # Create the unique index
    create_if_not_exists(
      index(:maps_v1, [:public_api_key],
        unique: true,
        name: :maps_v1_unique_public_api_key_index,
        where: "public_api_key IS NOT NULL"
      )
    )

    IO.puts("Created unique index on maps_v1.public_api_key")
  end

  defp create_backup_table do
    repo().query!(
      """
      CREATE TABLE IF NOT EXISTS maps_v1_api_key_backup (
        id UUID PRIMARY KEY,
        map_id UUID NOT NULL,
        old_public_api_key TEXT NOT NULL,
        reason TEXT NOT NULL,
        backed_up_at TIMESTAMP NOT NULL DEFAULT NOW()
      )
      """,
      []
    )

    IO.puts("Created backup table maps_v1_api_key_backup")
  end

  def down do
    drop_if_exists(index(:maps_v1, [:public_api_key], name: :maps_v1_unique_public_api_key_index))

    IO.puts("Dropped unique index on maps_v1.public_api_key")

    # Drop backup table
    repo().query!("DROP TABLE IF EXISTS maps_v1_api_key_backup", [])
    IO.puts("Dropped backup table maps_v1_api_key_backup")
  end

  defp check_and_fix_duplicates do
    # Check for duplicate non-null API keys
    duplicates_query = """
    SELECT public_api_key, COUNT(*) as cnt
    FROM maps_v1
    WHERE public_api_key IS NOT NULL
    GROUP BY public_api_key
    HAVING COUNT(*) > 1
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: []}} ->
        IO.puts("No duplicate API keys found")

      {:ok, %{rows: rows}} when length(rows) > 0 ->
        IO.puts("Found #{length(rows)} duplicate API key(s) - clearing duplicates...")

        # For each duplicate, keep the first (by inserted_at) and clear the rest
        Enum.each(rows, fn [api_key, count] ->
          IO.puts("  Processing duplicate key (#{count} occurrences)")

          # Get all IDs with this key, ordered by inserted_at
          ids_query = """
          SELECT id::text
          FROM maps_v1
          WHERE public_api_key = $1
          ORDER BY inserted_at ASC, id ASC
          """

          case repo().query(ids_query, [api_key]) do
            {:ok, %{rows: id_rows}} ->
              # Keep first, clear rest
              [_keep | clear_ids] = Enum.map(id_rows, fn [id] -> id end)

              Enum.each(clear_ids, fn id ->
                # Backup the API key before clearing
                backup_query = """
                INSERT INTO maps_v1_api_key_backup (id, map_id, old_public_api_key, reason)
                VALUES (gen_random_uuid(), $1::uuid, $2, 'duplicate_api_key_cleared_for_unique_index')
                """

                repo().query!(backup_query, [id, api_key])

                # Clear the duplicate
                clear_query = "UPDATE maps_v1 SET public_api_key = NULL WHERE id::text = $1"
                repo().query!(clear_query, [id])
                IO.puts("    Backed up and cleared API key for map #{id}")
              end)

            {:error, error} ->
              raise "Failed to get duplicate IDs for key: #{inspect(error)}"
          end
        end)

        IO.puts("Duplicate API keys cleared")

      {:error, error} ->
        raise "Failed to check for duplicate keys: #{inspect(error)}"
    end
  end
end
