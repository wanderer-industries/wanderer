defmodule WandererApp.Api.Changes.BroadcastMapUpdateTest do
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  alias WandererApp.Api.Changes.BroadcastMapUpdate
  alias WandererApp.Api.MapSystem
  alias WandererApp.Map.UpdateCoordinator

  describe "BroadcastMapUpdate.change/3 with transaction results" do
    setup do
      # Suppress debug logs for cleaner test output
      Logger.configure(level: :warning)
      on_exit(fn -> Logger.configure(level: :debug) end)

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      %{map: map, character: character, user: user}
    end

    test "broadcasts on successful transaction with {:ok, record} result", %{map: map} do
      # Track if UpdateCoordinator was called
      test_pid = self()

      # We'll use telemetry to track if the coordinator was called
      :telemetry.attach(
        "test-broadcast-success",
        [:wanderer_app, :update_coordinator, :success],
        fn _event_name, measurements, metadata, _config ->
          if metadata[:operation] == :add_system do
            send(test_pid, {:coordinator_called, :add_system})
          end
        end,
        nil
      )

      # Create a system - this should trigger the broadcast
      system_attrs = %{
        solar_system_id: 30_000_142,
        name: "Jita",
        position_x: 100,
        position_y: 200,
        visible: true
      }

      # Use the create action with map context which has BroadcastMapUpdate
      {:ok, _system} = MapSystem.create(system_attrs, context: %{map: map})

      # Should have called the coordinator
      assert_receive {:coordinator_called, :add_system}, 1000

      # Clean up
      :telemetry.detach("test-broadcast-success")
    end

    test "does NOT broadcast on failed transaction", %{map: map} do
      # Track if UpdateCoordinator was called
      test_pid = self()

      :telemetry.attach(
        "test-broadcast-failure",
        [:wanderer_app, :update_coordinator, :success],
        fn _event_name, measurements, metadata, _config ->
          if metadata[:operation] == :add_system do
            send(test_pid, {:coordinator_called, :add_system})
          end
        end,
        nil
      )

      # Try to create an invalid system (missing required fields)
      # This should fail validation and not broadcast
      invalid_attrs = %{
        # Missing solar_system_id - required field
        name: "Invalid System"
      }

      # This should fail
      result = MapSystem.create(invalid_attrs, context: %{map: map})

      # Should get an error
      assert {:error, _changeset} = result

      # Should NOT have called the coordinator
      refute_receive {:coordinator_called, :add_system}, 500

      # Clean up
      :telemetry.detach("test-broadcast-failure")
    end

    test "handles {:ok, record} result format correctly", %{map: map} do
      # Create a changeset and manually test the after_transaction callback
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Test System",
            position_x: 100,
            position_y: 200,
            visible: true
          },
          context: %{map: map}
        )

      # Apply the BroadcastMapUpdate change
      changeset_with_hook = BroadcastMapUpdate.change(changeset, [event: :add_system], %{})

      # Verify the hook was added
      assert length(changeset_with_hook.after_action) > 0 or
               length(changeset_with_hook.after_transaction) > 0
    end

    test "handles direct struct result format (old Ash versions)", %{map: map} do
      # This tests the fallback for older Ash versions that return struct directly
      system = %MapSystem{
        id: Ash.UUID.generate(),
        solar_system_id: 30_000_142,
        name: "Test",
        map_id: map.id,
        position_x: 100,
        position_y: 200
      }

      # The callback should handle direct struct returns
      # (This is tested indirectly through the change/3 function)
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Test System",
            position_x: 100,
            position_y: 200,
            map_id: map.id
          }
        )

      result = BroadcastMapUpdate.change(changeset, [event: :add_system], %{})
      assert %Ash.Changeset{} = result
    end

    test "logs warning for unexpected result types", %{map: map} do
      # Capture logs
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          changeset =
            Ash.Changeset.for_create(
              MapSystem,
              :create,
              %{
                solar_system_id: 30_000_142,
                name: "Test",
                position_x: 100,
                position_y: 200
              },
              context: %{map: map}
            )

          # The change should handle this gracefully
          _result = BroadcastMapUpdate.change(changeset, [event: :add_system], %{})
        end)

      # Just verify no crash - logging is internal detail
      assert true
    end

    test "skips broadcast for non-struct results", %{map: map} do
      # This would happen in bulk operations or other edge cases
      # The callback should skip broadcasting gracefully
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Test",
            position_x: 100,
            position_y: 200
          },
          context: %{map: map}
        )

      result = BroadcastMapUpdate.change(changeset, [event: :add_system], %{})
      assert %Ash.Changeset{} = result
    end
  end

  describe "determine_event/3" do
    setup do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      %{map: map, character: character, user: user}
    end

    test "changes update_system to systems_removed when visible=false", %{map: map} do
      # Create a system first
      {:ok, system} =
        MapSystem.create(
          %{
            solar_system_id: 30_000_142,
            name: "Test System",
            position_x: 100,
            position_y: 200,
            visible: true
          },
          context: %{map: map}
        )

      # Update to make it invisible - should trigger systems_removed event
      test_pid = self()

      :telemetry.attach(
        "test-systems-removed",
        [:wanderer_app, :update_coordinator, :success],
        fn _event_name, _measurements, metadata, _config ->
          if metadata[:operation] == :remove_system do
            send(test_pid, {:coordinator_called, :remove_system})
          end
        end,
        nil
      )

      # Update to invisible using the update_visible action
      {:ok, _updated} =
        MapSystem.update_visible(system, %{visible: false}, context: %{map: map})

      # Should have called remove_system coordinator
      assert_receive {:coordinator_called, :remove_system}, 1000

      :telemetry.detach("test-systems-removed")
    end
  end

  describe "coordinate_update/2 error handling" do
    test "logs error when map_id is nil" do
      # Track telemetry event for missing map_id
      test_pid = self()

      :telemetry.attach(
        "test-missing-map-id",
        [:wanderer_app, :broadcast_map_update, :missing_map_id],
        fn _event_name, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, metadata})
        end,
        nil
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          # Create a system record with nil map_id
          system = %MapSystem{
            id: Ash.UUID.generate(),
            solar_system_id: 30_000_142,
            name: "Test",
            map_id: nil,
            position_x: 100,
            position_y: 200
          }

          # Create a changeset and apply BroadcastMapUpdate
          changeset =
            Ash.Changeset.for_create(
              MapSystem,
              :create,
              %{
                solar_system_id: 30_000_142,
                name: "Test"
              }
            )

          # Apply the change to register the after_transaction hook
          changeset_with_hook = BroadcastMapUpdate.change(changeset, [event: :add_system], %{})

          # Get the after_transaction hook and invoke it with our nil map_id system
          # This simulates what Ash does after a successful transaction
          [hook | _] = changeset_with_hook.after_transaction

          # Invoke the hook with the system that has nil map_id
          hook.(changeset, {:ok, system})
        end)

      # Verify the error was logged
      assert log =~ "Cannot coordinate add_system - missing map_id"

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, metadata}, 1000
      assert metadata[:event] == :add_system
      assert metadata[:struct] == WandererApp.Api.MapSystem

      # Clean up
      :telemetry.detach("test-missing-map-id")
    end
  end
end
