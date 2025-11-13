defmodule WandererApp.Repo.Migrations.FixDuplicateMapSlugs do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Check for duplicates first
    has_duplicates = check_for_duplicates()

    # If duplicates exist, drop the index first to allow fixing them
    if has_duplicates do
      IO.puts("Duplicates found, dropping index before cleanup...")
      drop_index_if_exists()
    end

    # Fix duplicate slugs in maps_v1 table
    fix_duplicate_slugs()

    # Ensure unique index exists (recreate if needed)
    ensure_unique_index()
  end

  def down do
    # This migration is idempotent and safe to run multiple times
    # No need to revert as it only fixes data integrity issues
    :ok
  end

  defp check_for_duplicates do
    duplicates_query = """
    SELECT COUNT(*) as duplicate_count
    FROM (
      SELECT slug
      FROM maps_v1
      GROUP BY slug
      HAVING count(*) > 1
    ) duplicates
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: [[count]]}} when count > 0 ->
        IO.puts("Found #{count} duplicate slug(s)")
        true

      {:ok, %{rows: [[0]]}} ->
        false

      {:error, error} ->
        IO.puts("Error checking for duplicates: #{inspect(error)}")
        false
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
        IO.puts("Dropping existing unique index...")
        execute("DROP INDEX IF EXISTS maps_v1_unique_slug_index")
        IO.puts("✓ Index dropped")

      {:ok, %{rows: [[false]]}} ->
        IO.puts("No existing index to drop")

      {:error, error} ->
        IO.puts("Error checking index: #{inspect(error)}")
    end
  end

  defp fix_duplicate_slugs do
    # Get all duplicate slugs with their IDs
    duplicates_query = """
    SELECT slug, array_agg(id::text ORDER BY updated_at) as ids
    FROM maps_v1
    GROUP BY slug
    HAVING count(*) > 1
    """

    case repo().query(duplicates_query, []) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        IO.puts("Fixing #{length(rows)} duplicate slug(s)...")

        Enum.each(rows, fn [slug, ids] ->
          IO.puts("Processing duplicate slug: #{slug} (#{length(ids)} occurrences)")

          # Keep the first one (oldest), rename the rest
          [_keep_id | rename_ids] = ids

          rename_ids
          |> Enum.with_index(2)
          |> Enum.each(fn {id_string, n} ->
            new_slug = "#{slug}-#{n}"

            # Use parameterized query for safety
            update_query = "UPDATE maps_v1 SET slug = $1 WHERE id::text = $2"
            repo().query!(update_query, [new_slug, id_string])
            IO.puts("  ✓ Renamed #{id_string} to '#{new_slug}'")
          end)
        end)

        IO.puts("✓ All duplicate slugs fixed!")

      {:ok, %{rows: []}} ->
        IO.puts("No duplicate slugs to fix")

      {:error, error} ->
        IO.puts("Error checking for duplicates: #{inspect(error)}")
        raise "Failed to check for duplicate slugs: #{inspect(error)}"
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
        IO.puts("Unique index on slug already exists")

      {:ok, %{rows: [[false]]}} ->
        IO.puts("Creating unique index on slug...")

        create_if_not_exists index(:maps_v1, [:slug],
                               unique: true,
                               name: :maps_v1_unique_slug_index
                             )

        IO.puts("✓ Index created successfully!")

      {:error, error} ->
        IO.puts("Error checking index: #{inspect(error)}")
        raise "Failed to check index: #{inspect(error)}"
    end
  end
end
