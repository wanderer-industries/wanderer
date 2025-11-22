defmodule WandererApp.Repo.Migrations.UpdateMapSlugIndexIncludeDeleted do
  @moduledoc """
  Updates the unique index on maps_v1.slug to include deleted maps.

  Previously, the index only enforced uniqueness on non-deleted maps:
    WHERE deleted = false

  This migration updates it to enforce uniqueness across ALL maps,
  including deleted ones. This prevents confusion and ensures that a
  slug can always unambiguously identify a specific map in the system's history.

  The migration:
  1. Checks for any duplicate slugs (including deleted maps)
  2. Fixes duplicates by renaming newer maps
  3. Drops the old index (with WHERE clause)
  4. Creates new index without WHERE clause (applies to all rows)
  """
  use Ecto.Migration
  require Logger

  def up do
    IO.puts("\n=== Updating Map Slug Index to Include Deleted Maps ===\n")

    # Step 1: Check for duplicates across ALL maps (including deleted)
    duplicate_count = count_all_duplicates()

    if duplicate_count > 0 do
      IO.puts("Found #{duplicate_count} duplicate slug(s) across all maps (including deleted)")
      IO.puts("Fixing duplicates before updating index...\n")

      # Step 2: Drop existing index
      drop_existing_index()

      # Step 3: Fix all duplicates (including deleted maps)
      fix_all_duplicate_slugs()

      # Step 4: Create new index without WHERE clause
      create_new_index()
    else
      IO.puts("No duplicates found - updating index...\n")

      # Just update the index
      drop_existing_index()
      create_new_index()
    end

    # Step 5: Verify no duplicates remain
    verify_no_duplicates()

    IO.puts("\n=== Migration completed successfully! ===\n")
  end

  def down do
    IO.puts("\n=== Reverting Map Slug Index Update ===\n")

    # Drop the new index
    execute("DROP INDEX IF EXISTS maps_v1_unique_slug_index")

    # Recreate the old index with WHERE clause
    create_if_not_exists(
      index(:maps_v1, [:slug],
        unique: true,
        name: :maps_v1_unique_slug_index,
        where: "deleted = false"
      )
    )

    IO.puts("✓ Reverted to index with WHERE deleted = false clause")
  end

  defp count_all_duplicates do
    duplicates_query = """
    SELECT COUNT(*) as duplicate_count
    FROM (
      SELECT slug
      FROM maps_v1
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

  defp drop_existing_index do
    IO.puts("Dropping existing unique index...")
    execute("DROP INDEX IF EXISTS maps_v1_unique_slug_index")
    IO.puts("✓ Old index dropped\n")
  end

  defp fix_all_duplicate_slugs do
    # Get all duplicate slugs across ALL maps (including deleted)
    duplicates_query = """
    SELECT
      slug,
      array_agg(id::text ORDER BY inserted_at ASC, id ASC) as ids,
      array_agg(name ORDER BY inserted_at ASC, id ASC) as names,
      array_agg(deleted ORDER BY inserted_at ASC, id ASC) as deleted_flags
    FROM maps_v1
    GROUP BY slug
    HAVING COUNT(*) > 1
    ORDER BY slug
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        IO.puts("Fixing #{length(rows)} duplicate slug(s)...\n")

        Enum.each(rows, fn [slug, ids, names, deleted_flags] ->
          IO.puts("  Processing: '#{slug}' (#{length(ids)} duplicates)")

          # Keep the first one (oldest by inserted_at), rename the rest
          [keep_id | rename_ids] = ids
          [keep_name | rename_names] = names
          [keep_deleted | rename_deleted_flags] = deleted_flags

          deleted_str = if keep_deleted, do: " [DELETED]", else: ""
          IO.puts("    ✓ Keeping: #{keep_id} - '#{keep_name}'#{deleted_str}")

          # Rename duplicates
          rename_ids
          |> Enum.zip(rename_names)
          |> Enum.zip(rename_deleted_flags)
          |> Enum.with_index(2)
          |> Enum.each(fn {{{id_string, name}, is_deleted}, n} ->
            new_slug = generate_unique_slug(slug, n)

            # Use parameterized query for safety
            update_query = "UPDATE maps_v1 SET slug = $1 WHERE id::text = $2"
            repo().query!(update_query, [new_slug, id_string])

            deleted_str = if is_deleted, do: " [DELETED]", else: ""
            IO.puts("    → Renamed: #{id_string} - '#{name}'#{deleted_str} to '#{new_slug}'")
          end)
        end)

        IO.puts("\n✓ All duplicate slugs fixed!\n")

      {:ok, %{rows: []}} ->
        IO.puts("No duplicate slugs to fix\n")

      {:error, error} ->
        IO.puts("Error finding duplicates: #{inspect(error)}")
        raise "Failed to query duplicate slugs: #{inspect(error)}"
    end
  end

  defp generate_unique_slug(base_slug, n) when n >= 2 do
    candidate = "#{base_slug}-#{n}"

    # Check if this slug already exists across ALL maps (including deleted)
    check_query = "SELECT COUNT(*) FROM maps_v1 WHERE slug = $1"

    case repo().query!(check_query, [candidate]) do
      %{rows: [[0]]} ->
        candidate

      %{rows: [[_count]]} ->
        # Try next number
        generate_unique_slug(base_slug, n + 1)
    end
  end

  defp create_new_index do
    IO.puts("Creating new unique index (includes deleted maps)...")

    create_if_not_exists(
      index(:maps_v1, [:slug],
        unique: true,
        name: :maps_v1_unique_slug_index
      )
    )

    IO.puts("✓ New index created successfully!\n")
  end

  defp verify_no_duplicates do
    IO.puts("Verifying no duplicates remain...")

    remaining_duplicates = count_all_duplicates()

    if remaining_duplicates > 0 do
      IO.puts("❌ ERROR: #{remaining_duplicates} duplicate(s) still exist!")
      raise "Migration failed: duplicates still exist after cleanup"
    else
      IO.puts("✓ Verification passed: No duplicates found")
    end
  end
end
