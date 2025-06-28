defmodule WandererApp.DatabaseSetup do
  @moduledoc """
  Database setup utilities for the test environment.

  This module provides functions to:
  - Create and drop test databases
  - Run migrations
  - Seed test data
  - Reset database state between tests
  """

  require Logger

  alias WandererApp.Repo
  alias Ecto.Adapters.SQL

  @test_db_name "wanderer_test"

  @doc """
  Sets up the test database from scratch.
  Creates the database, runs migrations, and sets up initial data.
  """
  def setup_test_database do
    with :ok <- ensure_database_exists(),
         :ok <- run_migrations(),
         :ok <- verify_setup() do
      Logger.info("✅ Test database setup completed successfully")
      :ok
    else
      {:error, reason} ->
        Logger.error("❌ Test database setup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ensures the test database exists, creating it if necessary.
  """
  def ensure_database_exists do
    case create_database() do
      :ok ->
        Logger.info("📋 Test database ready")
        :ok

      {:error, :already_exists} ->
        Logger.info("📋 Test database already exists")
        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to create test database: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates the test database.
  """
  def create_database do
    repo_config = Repo.config()
    database = Keyword.get(repo_config, :database)

    case database do
      nil ->
        {:error, :no_database_configured}

      db_name ->
        create_database_if_not_exists(db_name, repo_config)
    end
  end

  @doc """
  Drops the test database. Use with caution!
  """
  def drop_database do
    repo_config = Repo.config()
    database = Keyword.get(repo_config, :database)

    Logger.warning("🗑️  Dropping test database: #{database}")

    # Stop the repo first
    if Process.whereis(Repo) do
      Supervisor.terminate_child(WandererApp.Supervisor, Repo)
    end

    # Drop the database
    config_without_db = Keyword.put(repo_config, :database, nil)

    case SQL.query(
           Ecto.Adapters.Postgres,
           "DROP DATABASE IF EXISTS \"#{database}\"",
           [],
           config_without_db
         ) do
      {:ok, _} ->
        Logger.info("✅ Test database dropped successfully")
        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to drop test database: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Runs all pending migrations on the test database.
  """
  def run_migrations do
    Logger.info("🏗️  Running migrations on test database...")

    case Ecto.Migrator.run(Repo, migrations_path(), :up, all: true) do
      migrations when is_list(migrations) ->
        Logger.info("✅ Migrations completed: #{length(migrations)} migrations applied")
        :ok

      {:error, reason} ->
        Logger.error("❌ Migration failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Rolls back the last migration.
  """
  def rollback_migration(steps \\ 1) do
    Logger.info("⏪ Rolling back #{steps} migration(s)...")

    case Ecto.Migrator.run(Repo, migrations_path(), :down, step: steps) do
      migrations when is_list(migrations) ->
        Logger.info("✅ Rollback completed: #{length(migrations)} migrations rolled back")
        :ok

      {:error, reason} ->
        Logger.error("❌ Rollback failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Resets the test database to a clean state.
  """
  def reset_database do
    Logger.info("🔄 Resetting test database...")

    with :ok <- truncate_all_tables(),
         :ok <- reset_sequences() do
      Logger.info("✅ Database reset completed")
      :ok
    else
      {:error, reason} ->
        Logger.error("❌ Database reset failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Seeds the database with test fixtures.
  """
  def seed_test_data do
    Logger.info("🌱 Seeding test data...")

    try do
      # Add your test data seeding logic here
      # For example:
      # WandererAppWeb.Factory.create_test_scenario()

      Logger.info("✅ Test data seeded successfully")
      :ok
    rescue
      error ->
        Logger.error("❌ Failed to seed test data: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Verifies that the database setup is correct.
  """
  def verify_setup do
    Logger.info("🔍 Verifying database setup...")

    try do
      # Test basic connectivity
      SQL.query!(Repo, "SELECT 1", [])

      # Verify key tables exist
      verify_table_exists("users")
      verify_table_exists("characters")
      verify_table_exists("maps")

      Logger.info("✅ Database verification completed")
      :ok
    rescue
      error ->
        Logger.error("❌ Database verification failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private functions

  defp create_database_if_not_exists(database, repo_config) do
    config_without_db = Keyword.put(repo_config, :database, nil)

    case SQL.query(
           Ecto.Adapters.Postgres,
           "CREATE DATABASE \"#{database}\"",
           [],
           config_without_db
         ) do
      {:ok, _} ->
        :ok

      {:error, %{postgres: %{code: :duplicate_database}}} ->
        {:error, :already_exists}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp truncate_all_tables do
    tables = get_all_tables()

    if length(tables) > 0 do
      tables_sql = Enum.join(tables, ", ")
      SQL.query!(Repo, "TRUNCATE TABLE #{tables_sql} RESTART IDENTITY CASCADE", [])
    end

    :ok
  end

  defp reset_sequences do
    # Reset any sequences that might not be handled by RESTART IDENTITY
    sequences = get_all_sequences()

    Enum.each(sequences, fn sequence ->
      SQL.query!(Repo, "ALTER SEQUENCE #{sequence} RESTART WITH 1", [])
    end)

    :ok
  end

  defp get_all_tables do
    result =
      SQL.query!(
        Repo,
        """
          SELECT tablename
          FROM pg_tables
          WHERE schemaname = 'public'
          AND tablename NOT LIKE '%_pkey'
          AND tablename != 'schema_migrations'
        """,
        []
      )

    result.rows |> List.flatten()
  end

  defp get_all_sequences do
    result =
      SQL.query!(
        Repo,
        """
          SELECT sequence_name
          FROM information_schema.sequences
          WHERE sequence_schema = 'public'
        """,
        []
      )

    result.rows |> List.flatten()
  end

  defp verify_table_exists(table_name) do
    result =
      SQL.query!(
        Repo,
        """
          SELECT COUNT(*)
          FROM information_schema.tables
          WHERE table_schema = 'public'
          AND table_name = $1
        """,
        [table_name]
      )

    case result.rows do
      [[1]] -> :ok
      _ -> raise "Table #{table_name} does not exist"
    end
  end

  defp migrations_path do
    Application.app_dir(:wanderer_app, "priv/repo/migrations")
  end
end
