defmodule WandererApp.Repo.Migrations.EnsureNoDuplicateMapSlugs do
  @moduledoc """
  Final migration to ensure all duplicate map slugs are removed and unique index exists.

  This migration:
  1. Checks for any remaining duplicate slugs
  2. Fixes duplicates by renaming them (keeps oldest, renames newer ones)
  3. Ensures unique index exists on maps_v1.slug
  4. Verifies no duplicates remain after migration

  Safe to run multiple times (idempotent).
  """
  use Ecto.Migration
  import Ecto.Query
  require Logger

  def up do
    IO.puts("\n=== Starting Map Slug Deduplication Migration ===\n")

    # Step 1: Check for duplicates
    duplicate_count = count_duplicates()

    if duplicate_count > 0 do
      IO.puts("Found #{duplicate_count} duplicate slug(s) - proceeding with cleanup...")

      # Step 2: Drop index temporarily if it exists (to allow updates)
      drop_index_if_exists()

      # Step 3: Fix all duplicates
      fix_duplicate_slugs()

      # Step 4: Recreate unique index
      ensure_unique_index()
    else
      IO.puts("No duplicate slugs found - ensuring unique index exists...")
      ensure_unique_index()
    end

    # Step 5: Final verification
    verify_no_duplicates()

    IO.puts("\n=== Migration completed successfully! ===\n")
  end

  def down do
    # This migration is idempotent and only fixes data integrity issues
    # No need to revert as it doesn't change schema in a harmful way
    IO.puts("This migration does not need to be reverted")
    :ok
  end

  defp count_duplicates do
    duplicates_query = """
    SELECT COUNT(*) as duplicate_count
    FROM (
      SELECT slug
      FROM maps_v1
      WHERE deleted = false
      GROUP BY slug
      HAVING COUNT(*) > 1
    ) duplicates
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: [[count]]}} ->
        count

      {:error, error} ->
        IO.puts("Error counting duplicates: #{inspect(error)}")
        0
    end
  end

  defp drop_index_if_exists do
    index_exists_query = """
    SELECT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = 'maps_v1'
      AND indexname = 'maps_v1_unique_slug_index'
    )
    """

    case repo().query(index_exists_query, []) do
      {:ok, %{rows: [[true]]}} ->
        IO.puts("Temporarily dropping unique index to allow updates...")
        execute("DROP INDEX IF EXISTS maps_v1_unique_slug_index")
        IO.puts("✓ Index dropped")

      {:ok, %{rows: [[false]]}} ->
        IO.puts("No existing index to drop")

      {:error, error} ->
        IO.puts("Error checking index: #{inspect(error)}")
    end
  end

  defp fix_duplicate_slugs do
    # Get all duplicate slugs with their IDs and timestamps
    # Order by inserted_at to keep the oldest one unchanged
    duplicates_query = """
    SELECT
      slug,
      array_agg(id::text ORDER BY inserted_at ASC, id ASC) as ids,
      array_agg(name ORDER BY inserted_at ASC, id ASC) as names
    FROM maps_v1
    WHERE deleted = false
    GROUP BY slug
    HAVING COUNT(*) > 1
    ORDER BY slug
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        IO.puts("\nFixing #{length(rows)} duplicate slug(s)...")

        Enum.each(rows, fn [slug, ids, names] ->
          IO.puts("\n  Processing: '#{slug}' (#{length(ids)} duplicates)")

          # Keep the first one (oldest by inserted_at), rename the rest
          [keep_id | rename_ids] = ids
          [keep_name | rename_names] = names

          IO.puts("    ✓ Keeping: #{keep_id} - '#{keep_name}'")

          # Rename duplicates
          rename_ids
          |> Enum.zip(rename_names)
          |> Enum.with_index(2)
          |> Enum.each(fn {{id_string, name}, n} ->
            new_slug = generate_unique_slug(slug, n)

            # Use parameterized query for safety
            update_query = "UPDATE maps_v1 SET slug = $1 WHERE id::text = $2"
            repo().query!(update_query, [new_slug, id_string])

            IO.puts("    → Renamed: #{id_string} - '#{name}' to slug '#{new_slug}'")
          end)
        end)

        IO.puts("\n✓ All duplicate slugs fixed!")

      {:ok, %{rows: []}} ->
        IO.puts("No duplicate slugs to fix")

      {:error, error} ->
        IO.puts("Error finding duplicates: #{inspect(error)}")
        raise "Failed to query duplicate slugs: #{inspect(error)}"
    end
  end

  defp generate_unique_slug(base_slug, n) when n >= 2 do
    candidate = "#{base_slug}-#{n}"

    # Check if this slug already exists
    check_query = "SELECT COUNT(*) FROM maps_v1 WHERE slug = $1 AND deleted = false"

    case repo().query!(check_query, [candidate]) do
      %{rows: [[0]]} ->
        candidate

      %{rows: [[_count]]} ->
        # Try next number
        generate_unique_slug(base_slug, n + 1)
    end
  end

  defp ensure_unique_index do
    # Check if index exists
    index_exists_query = """
    SELECT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = 'maps_v1'
      AND indexname = 'maps_v1_unique_slug_index'
    )
    """

    case repo().query(index_exists_query, []) do
      {:ok, %{rows: [[true]]}} ->
        IO.puts("✓ Unique index on slug already exists")

      {:ok, %{rows: [[false]]}} ->
        IO.puts("Creating unique index on slug column...")

        create_if_not_exists(
          index(:maps_v1, [:slug],
            unique: true,
            name: :maps_v1_unique_slug_index,
            where: "deleted = false"
          )
        )

        IO.puts("✓ Unique index created successfully!")

      {:error, error} ->
        IO.puts("Error checking index: #{inspect(error)}")
        raise "Failed to check index existence: #{inspect(error)}"
    end
  end

  defp verify_no_duplicates do
    IO.puts("\nVerifying no duplicates remain...")

    remaining_duplicates = count_duplicates()

    if remaining_duplicates > 0 do
      IO.puts("❌ ERROR: #{remaining_duplicates} duplicate(s) still exist!")
      raise "Migration failed: duplicates still exist after cleanup"
    else
      IO.puts("✓ Verification passed: No duplicates found")
    end
  end
end
