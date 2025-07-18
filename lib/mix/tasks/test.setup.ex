defmodule Mix.Tasks.Test.Setup do
  @moduledoc """
  Sets up the test database environment.

  This task will:
  - Create the test database if it doesn't exist
  - Run all migrations
  - Verify the setup is correct

  ## Usage

      mix test.setup

  ## Options

      --force     Drop the existing test database and recreate it
      --quiet     Reduce output verbosity
      --seed      Seed the database with test fixtures after setup

  ## Examples

      mix test.setup
      mix test.setup --force
      mix test.setup --seed
      mix test.setup --force --seed --quiet

  """

  use Mix.Task

  alias WandererApp.DatabaseSetup

  @shortdoc "Sets up the test database environment"

  @impl Mix.Task
  def run(args) do
    # Parse options
    {opts, _} =
      OptionParser.parse!(args,
        strict: [force: :boolean, quiet: :boolean, seed: :boolean],
        aliases: [f: :force, q: :quiet, s: :seed]
      )

    # Configure logger level based on quiet option
    if opts[:quiet] do
      Logger.configure(level: :warning)
    else
      Logger.configure(level: :info)
    end

    # Set the environment to test
    Mix.env(:test)

    try do
      # Load the application configuration
      Mix.Task.run("loadconfig")

      # Start the application
      {:ok, _} = Application.ensure_all_started(:wanderer_app)

      if opts[:force] do
        Mix.shell().info("🔄 Forcing database recreation...")
        _ = DatabaseSetup.drop_database()
      end

      case DatabaseSetup.setup_test_database() do
        :ok ->
          if opts[:seed] do
            Mix.shell().info("🌱 Seeding test data...")

            case DatabaseSetup.seed_test_data() do
              :ok ->
                Mix.shell().info("✅ Test database setup and seeding completed successfully!")

              {:error, reason} ->
                Mix.shell().error("❌ Test data seeding failed: #{inspect(reason)}")
                System.halt(1)
            end
          else
            Mix.shell().info("✅ Test database setup completed successfully!")
          end

        {:error, reason} ->
          Mix.shell().error("❌ Test database setup failed: #{inspect(reason)}")
          print_troubleshooting_help()
          System.halt(1)
      end
    rescue
      error ->
        Mix.shell().error("❌ Unexpected error during database setup: #{inspect(error)}")
        print_troubleshooting_help()
        System.halt(1)
    end
  end

  defp print_troubleshooting_help do
    Mix.shell().info("""

    🔧 Troubleshooting Tips:

    1. Ensure PostgreSQL is running:
       • On macOS: brew services start postgresql
       • On Ubuntu: sudo service postgresql start
       • Using Docker: docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres

    2. Check database configuration in config/test.exs:
       • Username: postgres
       • Password: postgres
       • Host: localhost
       • Port: 5432

    3. Verify database permissions:
       • Ensure the postgres user can create databases
       • Try connecting manually: psql -U postgres -h localhost

    4. For connection refused errors:
       • Check if PostgreSQL is listening on the correct port
       • Verify firewall settings

    5. Force recreation if corrupted:
       • Run: mix test.setup --force

    📚 For more help, see: https://hexdocs.pm/ecto/Ecto.Adapters.Postgres.html
    """)
  end
end
