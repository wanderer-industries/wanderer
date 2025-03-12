defmodule WandererApp.Repo do
  use AshPostgres.Repo,
    otp_app: :wanderer_app

  def installed_extensions do
    # Ash installs some functions that it needs to run the
    # first time you generate migrations.
    ["ash-functions"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
