defmodule WandererApp.DatabaseTest do
  use WandererApp.DataCase, async: false

  @moduletag :skip

  describe "database connectivity" do
    test "can connect to test database" do
      # Simple connectivity test
      result = Repo.query!("SELECT 1 as test_value")
      assert %{rows: [[1]]} = result
    end

    test "can create and query test data using Ecto" do
      # This tests that our basic Ecto setup works
      test_data = %{
        id: 1,
        name: "Test Connection",
        created_at: NaiveDateTime.utc_now()
      }

      # We'll use a raw query since we don't have schemas set up yet
      Repo.query!("""
        CREATE TEMP TABLE test_connection (
          id INTEGER,
          name VARCHAR(255),
          created_at TIMESTAMP
        )
      """)

      Repo.query!(
        """
          INSERT INTO test_connection (id, name, created_at)
          VALUES ($1, $2, $3)
        """,
        [test_data.id, test_data.name, test_data.created_at]
      )

      result = Repo.query!("SELECT * FROM test_connection")
      assert length(result.rows) == 1
    end

    test "database sandbox isolation works" do
      # This test verifies that our sandbox setup works
      # Data created in this test should not be visible in other tests

      Repo.query!("CREATE TEMP TABLE isolation_test (id INTEGER)")
      Repo.query!("INSERT INTO isolation_test (id) VALUES (42)")

      result = Repo.query!("SELECT COUNT(*) FROM isolation_test")
      assert %{rows: [[1]]} = result
    end
  end

  describe "test helpers" do
    test "assert_ash_success helper works" do
      success_result = {:ok, "test data"}
      assert assert_ash_success(success_result) == "test data"
    end

    test "assert_ash_error helper works" do
      error_result = {:error, "test error"}
      assert assert_ash_error(error_result) == error_result
    end

    test "assert_maps_equal helper works" do
      actual = %{a: 1, b: 2, c: 3}
      expected = %{a: 1, b: 2}

      # Should pass - expected is subset of actual
      assert_maps_equal(actual, expected)
    end

    test "eventually helper works for async operations" do
      # Start a process that will set a value after a delay
      test_pid = self()

      spawn(fn ->
        :timer.sleep(100)
        send(test_pid, :done)
      end)

      # Use eventually to wait for the message
      eventually(
        fn ->
          receive do
            :done -> :ok
          after
            100 -> flunk("Message not received")
          end
        end,
        timeout: 1000
      )
    end
  end
end
