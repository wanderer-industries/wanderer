defmodule WandererAppWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WandererAppWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint WandererAppWeb.Endpoint

      use WandererAppWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WandererAppWeb.ConnCase
    end
  end

  setup tags do
    # Tag this as a ConnCase test for shared sandbox mode
    tags = Map.put(tags, :conn_case, true)

    WandererApp.DataCase.setup_sandbox(tags)

    # Set up mocks for this test process
    WandererApp.Test.Mocks.setup_test_mocks()

    # Set up integration test environment (including Map.Manager)
    WandererApp.Test.IntegrationConfig.setup_integration_environment()
    WandererApp.Test.IntegrationConfig.setup_test_reliability_configs()

    # Cleanup after test
    on_exit(fn ->
      WandererApp.Test.IntegrationConfig.cleanup_integration_environment()
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Creates an active subscription for a map to bypass subscription checks in tests.
  Call this in your test setup after creating a map if subscriptions are enabled.
  """
  def create_active_subscription_for_map(map_id) do
    if WandererApp.Env.map_subscriptions_enabled?() do
      {:ok, _subscription} =
        Ash.create(WandererApp.Api.MapSubscription, %{
          map_id: map_id,
          plan: :omega,
          characters_limit: 100,
          hubs_limit: 10,
          auto_renew?: true,
          active_till: DateTime.utc_now() |> DateTime.add(30, :day)
        })
    end

    :ok
  end
end
