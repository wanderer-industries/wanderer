defmodule WandererApp.Repo.Migrations.AddPublicApiKeyUniqueIndex do
  @moduledoc """
  Adds a unique index on the public_api_key column of maps_v1.

  This migration:
  1. Creates a unique index on public_api_key where the value is not null
  2. Allows multiple NULL values (maps without API keys)
  3. Ensures all non-NULL API keys are unique

  The partial index (WHERE public_api_key IS NOT NULL) is used because:
  - Most maps won't have an API key set
  - We only care about uniqueness for maps that do have one
  - PostgreSQL's unique constraints on nullable columns already allow multiple NULLs,
    but a partial index is more explicit and efficient
  """
  use Ecto.Migration

  def up do
    # First, check for any duplicate non-null API keys and handle them
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

  def down do
    drop_if_exists(
      index(:maps_v1, [:public_api_key],
        name: :maps_v1_unique_public_api_key_index
      )
    )

    IO.puts("Dropped unique index on maps_v1.public_api_key")
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
                clear_query = "UPDATE maps_v1 SET public_api_key = NULL WHERE id::text = $1"
                repo().query!(clear_query, [id])
                IO.puts("    Cleared API key for map #{id}")
              end)

            {:error, error} ->
              IO.puts("Error getting IDs: #{inspect(error)}")
          end
        end)

        IO.puts("Duplicate API keys cleared")

      {:error, error} ->
        IO.puts("Error checking for duplicates: #{inspect(error)}")
    end
  end
end
