defmodule WandererApp.Repo do
  use AshPostgres.Repo,
    otp_app: :wanderer_app

  def installed_extensions do
    # Ash installs some functions that it needs to run the
    # first time you generate migrations.
    ["ash-functions"]
  end

  def min_pg_version do
    %Version{major: 15, minor: 0, patch: 0}
  end

  @doc """
  Dynamically configure the repository based on the runtime environment.
  In test environment, ensure we use the sandbox pool.
  """
  def init(_type, config) do
    if Application.get_env(:wanderer_app, :environment) == :test ||
         System.get_env("MIX_ENV") == "test" do
      # Force sandbox pool in test environment
      {:ok, Keyword.put(config, :pool, Ecto.Adapters.SQL.Sandbox)}
    else
      {:ok, config}
    end
  end
end
