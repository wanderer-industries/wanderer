defmodule WandererApp.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :wanderer_app
  @start_apps [
    :postgrex,
    :ecto
  ]

  def createdb(repos \\ repos()) do
    prepare()

    for repo <- repos do
      :ok = ensure_repo_created(repo)
    end

    IO.puts("Creation of Db successful!")
  end

  def migrate(repos \\ repos()) do
    IO.puts("Run migrations..")
    prepare()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :init.stop()
  end

  @doc """
  `interweave_migrate/0` is a migration function that:

  - Lists all pending migrations across multiple repositories.
  - Sorts these migrations into a single list.
  - Groups consecutive migrations by repository into "streaks".
  - Executes the migrations in the correct order by processing each streak sequentially.

  ### Why Use This Approach?

  This function resolves dependencies between migrations that span across different repositories.
  The default `migrate/0` function migrates each repository independently, which may result in
  migrations running in the wrong order when there are cross-repository dependencies.

  Consider the following example (adapted from reality, not 100% accurate):

  - **Migration 1**: The PostgreSQL (PG) repository creates a table named `site_imports`.
  - **Migration 2**: The ClickHouse (CH) repository creates `import_id` columns in `imported_*` tables.
  - **Migration 3**: The PG repository runs a data migration that utilizes both PG and CH databases,
    reading from the `import_id` column in `imported_*` tables.

  The default `migrate/0` would execute these migrations by repository, resulting in the following order:

  1. Migration 1 (PG)
  2. Migration 3 (PG)
  3. Migration 2 (CH)

  This sequence would fail at Migration 3, as the `import_id` columns in the CH repository have not been created yet.

  `interweave_migrate/0` addresses this issue by consolidating all pending migrations into a single, ordered queue:

  1. Migration 1 (PG)
  2. Migration 2 (CH)
  3. Migration 3 (PG)

  This ensures all dependencies are resolved in the correct order.
  """
  def interweave_migrate(repos \\ repos()) do
    prepare()

    pending = all_pending_migrations(repos)
    streaks = migration_streaks(pending)

    Enum.each(streaks, fn {repo, up_to_version} ->
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, to: up_to_version))
    end)
  end

  defp migration_streaks(pending_migrations) do
    sorted_migrations =
      pending_migrations
      |> Enum.map(fn {repo, version, _name} -> {repo, version} end)
      |> Enum.sort_by(fn {_repo, version} -> version end, :asc)

    streaks_reversed =
      Enum.reduce(sorted_migrations, [], fn {repo, _version} = latest_migration, streaks_acc ->
        case streaks_acc do
          # start the streak for repo
          [] -> [latest_migration]
          # extend the streak
          [{^repo, _prev_version} | rest] -> [latest_migration | rest]
          # end the streak for prev_repo, start the streak for repo
          [{_prev_repo, _prev_version} | _rest] -> [latest_migration | streaks_acc]
        end
      end)

    :lists.reverse(streaks_reversed)
  end

  @spec all_pending_migrations([Ecto.Repo.t()]) :: [{Ecto.Repo.t(), integer, String.t()}]
  defp all_pending_migrations(repos) do
    Enum.flat_map(repos, fn repo ->
      # credo:disable-for-lines:6 Credo.Check.Refactor.Nesting
      {:ok, pending, _started} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.migrations(repo)
          |> Enum.filter(fn {status, _version, _name} -> status == :down end)
          |> Enum.map(fn {_status, version, name} -> {repo, version, name} end)
        end)

      pending
    end)
  end

  def pending_streaks(repos \\ repos()) do
    prepare()
    IO.puts("Collecting pending migrations..")

    pending = all_pending_migrations(repos)

    if pending == [] do
      IO.puts("No pending migrations!")
    else
      streaks = migration_streaks(pending)
      print_migration_streaks(streaks, pending)
    end
  end

  defp print_migration_streaks([{repo, up_to_version} | streaks], pending) do
    {streak, pending} =
      Enum.split_with(pending, fn {pending_repo, version, _name} ->
        pending_repo == repo and version <= up_to_version
      end)

    IO.puts(
      "\n#{inspect(repo)} [#{Path.relative_to_cwd(Ecto.Migrator.migrations_path(repo))}] streak up to version #{up_to_version}:"
    )

    Enum.each(streak, fn {_repo, version, name} -> IO.puts("  * #{version}_#{name}") end)
    print_migration_streaks(streaks, pending)
  end

  defp print_migration_streaks([], []), do: :ok

  def rollback do
    prepare()

    get_step =
      IO.gets("Enter the number of steps: ")
      |> String.trim()
      |> Integer.parse()

    case get_step do
      {int, _trailing} ->
        Enum.each(repos(), fn repo -> run_rollbacks_for(repo, int) end)
        IO.puts("Rollback successful!")

      :error ->
        IO.puts("Invalid integer")
    end
  end

  def rollback(repo, version) do
    prepare()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp ensure_repo_created(repo) do
    config = repo.config()
    adapter = repo.__adapter__()

    case adapter.storage_status(config) do
      :up ->
        IO.puts("#{inspect(repo)} database already exists")
        :ok

      :down ->
        IO.puts("Creating #{inspect(repo)} database..")

        case adapter.storage_up(config) do
          :ok -> :ok
          {:error, :already_up} -> :ok
          {:error, _reason} = error -> error
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp run_rollbacks_for(repo, step) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running rollbacks for #{app} (STEP=#{step})")

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, all: false, step: step))
  end

  defp prepare do
    IO.puts("Loading #{@app}..")
    # Load the code for myapp, but don't start it
    :ok = Application.ensure_loaded(@app)

    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for myapp
    IO.puts("Starting repos..")
    Enum.each(repos(), & &1.start_link(pool_size: 2))
  end
end
