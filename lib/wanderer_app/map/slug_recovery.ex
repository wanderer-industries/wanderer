defmodule WandererApp.Map.SlugRecovery do
  @moduledoc """
  Handles automatic recovery from duplicate map slug scenarios.

  This module provides functions to:
  - Detect duplicate slugs in the database (including deleted maps)
  - Automatically fix duplicates by renaming newer maps
  - Verify and recreate unique indexes (enforced on all maps, including deleted)
  - Safely handle race conditions during recovery

  ## Slug Uniqueness Policy

  All map slugs must be unique across the entire maps_v1 table, including
  deleted maps. This prevents confusion and ensures that a slug can always
  unambiguously identify a specific map in the system's history.

  The recovery process is designed to be:
  - Idempotent (safe to run multiple times)
  - Production-safe (minimal locking, fast execution)
  - Observable (telemetry events for monitoring)
  """

  require Logger
  alias WandererApp.Repo

  @doc """
  Recovers from a duplicate slug scenario for a specific slug.

  This function:
  1. Finds all maps with the given slug (including deleted)
  2. Keeps the oldest map with the original slug
  3. Renames newer duplicates with numeric suffixes
  4. Verifies the unique index exists

  Returns:
  - `{:ok, result}` - Recovery successful
  - `{:error, reason}` - Recovery failed

  ## Examples

      iex> recover_duplicate_slug("home-2")
      {:ok, %{fixed_count: 1, kept_map_id: "...", renamed_maps: [...]}}
  """
  def recover_duplicate_slug(slug) do
    start_time = System.monotonic_time(:millisecond)

    Logger.warning("Starting slug recovery for '#{slug}'",
      slug: slug,
      operation: :recover_duplicate_slug
    )

    :telemetry.execute(
      [:wanderer_app, :map, :slug_recovery, :start],
      %{system_time: System.system_time()},
      %{slug: slug, operation: :recover_duplicate_slug}
    )

    result =
      Repo.transaction(fn ->
        # Find all maps with this slug (including deleted), ordered by insertion time
        duplicates = find_duplicate_maps(slug)

        case duplicates do
          [] ->
            Logger.info("No maps found with slug '#{slug}' during recovery")
            %{fixed_count: 0, kept_map_id: nil, renamed_maps: []}

          [_single_map] ->
            Logger.info("Only one map found with slug '#{slug}', no recovery needed")
            %{fixed_count: 0, kept_map_id: nil, renamed_maps: []}

          [kept_map | maps_to_rename] ->
            # Convert binary UUID to string for consistency
            kept_map_id_str =
              if is_binary(kept_map.id), do: Ecto.UUID.load!(kept_map.id), else: kept_map.id

            Logger.warning(
              "Found #{length(maps_to_rename)} duplicate maps for slug '#{slug}', fixing...",
              slug: slug,
              kept_map_id: kept_map_id_str,
              duplicate_count: length(maps_to_rename)
            )

            # Rename the duplicate maps
            renamed_maps =
              maps_to_rename
              |> Enum.with_index(2)
              |> Enum.map(fn {map, index} ->
                new_slug = generate_unique_slug(slug, index)
                rename_map(map, new_slug)
              end)

            %{
              fixed_count: length(renamed_maps),
              kept_map_id: kept_map_id_str,
              renamed_maps: renamed_maps
            }
        end
      end)

    case result do
      {:ok, recovery_result} ->
        duration = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:wanderer_app, :map, :slug_recovery, :complete],
          %{
            duration_ms: duration,
            fixed_count: recovery_result.fixed_count,
            system_time: System.system_time()
          },
          %{slug: slug, result: recovery_result}
        )

        Logger.info("Slug recovery completed successfully",
          slug: slug,
          fixed_count: recovery_result.fixed_count,
          duration_ms: duration
        )

        {:ok, recovery_result}

      {:error, reason} = error ->
        duration = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:wanderer_app, :map, :slug_recovery, :error],
          %{duration_ms: duration, system_time: System.system_time()},
          %{slug: slug, error: inspect(reason)}
        )

        Logger.error("Slug recovery failed",
          slug: slug,
          error: inspect(reason),
          duration_ms: duration
        )

        error
    end
  end

  @doc """
  Verifies that the unique index on map slugs exists.
  If missing, attempts to create it (after fixing any duplicates).

  Returns:
  - `{:ok, :exists}` - Index already exists
  - `{:ok, :created}` - Index was created
  - `{:error, reason}` - Failed to create index
  """
  def verify_unique_index do
    Logger.debug("Verifying unique index on maps_v1.slug")

    # Check if the index exists
    index_query = """
    SELECT 1
    FROM pg_indexes
    WHERE tablename = 'maps_v1'
      AND indexname = 'maps_v1_unique_slug_index'
    LIMIT 1
    """

    case Repo.query(index_query, []) do
      {:ok, %{rows: [[1]]}} ->
        Logger.debug("Unique index exists")
        {:ok, :exists}

      {:ok, %{rows: []}} ->
        Logger.warning("Unique index missing, attempting to create")
        create_unique_index()

      {:error, reason} ->
        Logger.error("Failed to check for unique index", error: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Performs a full recovery scan of all maps, fixing any duplicates found.
  Processes both deleted and non-deleted maps.

  This function will:
  1. Drop the unique index if it exists (to allow fixing duplicates)
  2. Find and fix all duplicate slugs
  3. Return statistics about the recovery

  Note: This function does NOT recreate the index. Call `verify_unique_index/0`
  after this function completes to ensure the index is recreated.

  This is a more expensive operation and should be run:
  - During maintenance windows
  - After detecting multiple duplicate slug errors
  - As part of deployment verification

  Returns:
  - `{:ok, stats}` - Recovery completed with statistics
  - `{:error, reason}` - Recovery failed
  """
  def recover_all_duplicates do
    Logger.info("Starting full duplicate slug recovery (including deleted maps)")

    start_time = System.monotonic_time(:millisecond)

    :telemetry.execute(
      [:wanderer_app, :map, :full_recovery, :start],
      %{system_time: System.system_time()},
      %{}
    )

    # Drop the unique index if it exists to allow fixing duplicates
    drop_unique_index_if_exists()

    # Find all slugs that have duplicates (including deleted maps)
    duplicate_slugs_query = """
    SELECT slug, COUNT(*) as count
    FROM maps_v1
    GROUP BY slug
    HAVING COUNT(*) > 1
    """

    case Repo.query(duplicate_slugs_query, []) do
      {:ok, %{rows: []}} ->
        Logger.info("No duplicate slugs found")
        {:ok, %{total_slugs_fixed: 0, total_maps_renamed: 0}}

      {:ok, %{rows: duplicate_rows}} ->
        Logger.warning("Found #{length(duplicate_rows)} slugs with duplicates",
          duplicate_count: length(duplicate_rows)
        )

        # Fix each duplicate slug
        results =
          Enum.map(duplicate_rows, fn [slug, _count] ->
            case recover_duplicate_slug(slug) do
              {:ok, result} -> result
              {:error, _} -> %{fixed_count: 0, kept_map_id: nil, renamed_maps: []}
            end
          end)

        stats = %{
          total_slugs_fixed: length(results),
          total_maps_renamed: Enum.sum(Enum.map(results, & &1.fixed_count))
        }

        duration = System.monotonic_time(:millisecond) - start_time

        :telemetry.execute(
          [:wanderer_app, :map, :full_recovery, :complete],
          %{
            duration_ms: duration,
            slugs_fixed: stats.total_slugs_fixed,
            maps_renamed: stats.total_maps_renamed,
            system_time: System.system_time()
          },
          %{stats: stats}
        )

        Logger.info("Full recovery completed",
          stats: stats,
          duration_ms: duration
        )

        {:ok, stats}

      {:error, reason} = error ->
        Logger.error("Failed to query for duplicates", error: inspect(reason))
        error
    end
  end

  # Private functions

  defp find_duplicate_maps(slug) do
    # Find all maps (including deleted) with this slug
    query = """
    SELECT id, name, slug, deleted, inserted_at
    FROM maps_v1
    WHERE slug = $1
    ORDER BY inserted_at ASC
    """

    case Repo.query(query, [slug]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, slug, deleted, inserted_at] ->
          %{id: id, name: name, slug: slug, deleted: deleted, inserted_at: inserted_at}
        end)

      {:error, reason} ->
        Logger.error("Failed to query for duplicate maps",
          slug: slug,
          error: inspect(reason)
        )

        []
    end
  end

  defp rename_map(map, new_slug) do
    # Convert binary UUID to string for logging
    map_id_str = if is_binary(map.id), do: Ecto.UUID.load!(map.id), else: map.id

    Logger.info("Renaming map #{map_id_str} from '#{map.slug}' to '#{new_slug}'",
      map_id: map_id_str,
      old_slug: map.slug,
      new_slug: new_slug,
      deleted: map.deleted
    )

    update_query = """
    UPDATE maps_v1
    SET slug = $1, updated_at = NOW()
    WHERE id = $2
    """

    case Repo.query(update_query, [new_slug, map.id]) do
      {:ok, _} ->
        Logger.info("Successfully renamed map #{map_id_str} to '#{new_slug}'")

        %{
          map_id: map_id_str,
          old_slug: map.slug,
          new_slug: new_slug,
          map_name: map.name,
          deleted: map.deleted
        }

      {:error, reason} ->
        map_id_str = if is_binary(map.id), do: Ecto.UUID.load!(map.id), else: map.id

        Logger.error("Failed to rename map #{map_id_str}",
          map_id: map_id_str,
          old_slug: map.slug,
          new_slug: new_slug,
          error: inspect(reason)
        )

        %{
          map_id: map_id_str,
          old_slug: map.slug,
          new_slug: nil,
          error: reason
        }
    end
  end

  defp generate_unique_slug(base_slug, index) do
    candidate = "#{base_slug}-#{index}"

    # Verify this slug is actually unique (check all maps, including deleted)
    query = "SELECT 1 FROM maps_v1 WHERE slug = $1 LIMIT 1"

    case Repo.query(query, [candidate]) do
      {:ok, %{rows: []}} ->
        candidate

      {:ok, %{rows: [[1]]}} ->
        # This slug is taken, try the next one
        generate_unique_slug(base_slug, index + 1)

      {:error, _} ->
        # On error, be conservative and try next number
        generate_unique_slug(base_slug, index + 1)
    end
  end

  defp create_unique_index do
    Logger.warning("Creating unique index on maps_v1.slug")

    # Create index on all maps (including deleted ones)
    # This enforces slug uniqueness across all maps regardless of deletion status
    create_index_query = """
    CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS maps_v1_unique_slug_index
    ON maps_v1 (slug)
    """

    case Repo.query(create_index_query, []) do
      {:ok, _} ->
        Logger.info("Successfully created unique index (includes deleted maps)")

        :telemetry.execute(
          [:wanderer_app, :map, :index_created],
          %{system_time: System.system_time()},
          %{index_name: "maps_v1_unique_slug_index"}
        )

        {:ok, :created}

      {:error, reason} ->
        Logger.error("Failed to create unique index", error: inspect(reason))
        {:error, reason}
    end
  end

  defp drop_unique_index_if_exists do
    Logger.debug("Checking if unique index exists before recovery")

    check_query = """
    SELECT 1
    FROM pg_indexes
    WHERE tablename = 'maps_v1'
      AND indexname = 'maps_v1_unique_slug_index'
    LIMIT 1
    """

    case Repo.query(check_query, []) do
      {:ok, %{rows: [[1]]}} ->
        Logger.info("Dropping unique index to allow duplicate recovery")
        drop_query = "DROP INDEX IF EXISTS maps_v1_unique_slug_index"

        case Repo.query(drop_query, []) do
          {:ok, _} ->
            Logger.info("Successfully dropped unique index")
            :ok

          {:error, reason} ->
            Logger.warning("Failed to drop unique index", error: inspect(reason))
            :ok
        end

      {:ok, %{rows: []}} ->
        Logger.debug("Unique index does not exist, no need to drop")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to check for unique index", error: inspect(reason))
        :ok
    end
  end
end
