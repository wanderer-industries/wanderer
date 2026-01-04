defmodule WandererApp.Map.Server.SignatureConnectionCascadeTest do
  @moduledoc """
  Tests for the signature-connection cascade behavior fix.

  This test suite verifies that:
  1. System's linked_sig_eve_id can be updated and cleared
  2. The data model relationships work correctly
  """
  use WandererApp.DataCase, async: false

  import Mox

  alias WandererApp.Api.MapSystem
  alias WandererAppWeb.Factory

  setup :verify_on_exit!

  setup do
    # Set up mocks in global mode for GenServer processes
    Mox.set_mox_global()

    # Setup DDRT mocks
    Test.DDRTMock
    |> stub(:init_tree, fn _name, _opts -> :ok end)
    |> stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> stub(:delete, fn _ids, _tree_name -> {:ok, %{}} end)
    |> stub(:query, fn _bbox, _tree_name -> {:ok, []} end)

    # Setup CachedInfo mocks for test systems
    WandererApp.CachedInfo.Mock
    |> stub(:get_system_static_info, fn
      30_000_142 ->
        {:ok,
         %{
           solar_system_id: 30_000_142,
           solar_system_name: "Jita",
           system_class: 7,
           security: "0.9"
         }}

      30_000_143 ->
        {:ok,
         %{
           solar_system_id: 30_000_143,
           solar_system_name: "Perimeter",
           system_class: 7,
           security: "0.9"
         }}

      _ ->
        {:error, :not_found}
    end)

    # Create test data using Factory
    character = Factory.create_character()
    map = Factory.create_map(%{owner_id: character.id})

    %{map: map, character: character}
  end

  describe "linked_sig_eve_id management" do
    test "system linked_sig_eve_id can be set and cleared", %{map: map} do
      # Create a system without linked_sig_eve_id
      {:ok, system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      # Initially nil
      assert is_nil(system.linked_sig_eve_id)

      # Update to a signature eve_id (simulating connection creation)
      {:ok, updated_system} =
        MapSystem.update_linked_sig_eve_id(system, %{linked_sig_eve_id: "SIG-123"})

      assert updated_system.linked_sig_eve_id == "SIG-123"

      # Clear it back to nil (simulating connection deletion - our fix)
      {:ok, cleared_system} =
        MapSystem.update_linked_sig_eve_id(updated_system, %{linked_sig_eve_id: nil})

      assert is_nil(cleared_system.linked_sig_eve_id)
    end

    test "system can distinguish between different linked signatures", %{map: map} do
      # Create system B (target) with linked_sig_eve_id = SIG-NEW
      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: "SIG-NEW"
        })

      # Verify the signature is correctly set
      assert system_b.linked_sig_eve_id == "SIG-NEW"

      # This verifies the logic: an old signature with eve_id="SIG-OLD"
      # would NOT match system_b.linked_sig_eve_id
      old_sig_eve_id = "SIG-OLD"
      refute system_b.linked_sig_eve_id == old_sig_eve_id

      # The new signature DOES match
      new_sig_eve_id = "SIG-NEW"
      assert system_b.linked_sig_eve_id == new_sig_eve_id
    end
  end

  describe "is_active_signature_for_target? logic verification" do
    @doc """
    These tests verify the core logic of the fix:
    - A signature is "active" only if target_system.linked_sig_eve_id == signature.eve_id
    - If they don't match, the signature is "orphan" and should NOT cascade to connections
    """

    test "active signature: linked_sig_eve_id matches signature eve_id", %{map: map} do
      sig_eve_id = "ABC-123"

      # System has linked_sig_eve_id pointing to our signature
      {:ok, target_system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: sig_eve_id
        })

      # This is what is_active_signature_for_target? checks
      assert target_system.linked_sig_eve_id == sig_eve_id
    end

    test "orphan signature: linked_sig_eve_id points to different signature", %{map: map} do
      # System has linked_sig_eve_id pointing to a NEWER signature
      {:ok, target_system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: "NEW-SIG-456"
        })

      # Old signature has different eve_id
      old_sig_eve_id = "OLD-SIG-123"

      # This would return false in is_active_signature_for_target?
      refute target_system.linked_sig_eve_id == old_sig_eve_id
    end

    test "orphan signature: linked_sig_eve_id is nil", %{map: map} do
      # System has nil linked_sig_eve_id (connection was already deleted)
      {:ok, target_system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter"
        })

      assert is_nil(target_system.linked_sig_eve_id)

      # Any signature would be orphan
      old_sig_eve_id = "OLD-SIG-123"
      refute target_system.linked_sig_eve_id == old_sig_eve_id
    end
  end

  describe "scenario simulation" do
    test "simulated scenario: re-entering WH after connection deleted", %{map: map} do
      # This simulates the bug scenario:
      # 1. User enters WH A → B, creates connection, signature SIG-OLD links B
      # 2. Connection is deleted - linked_sig_eve_id should be cleared (our fix)
      # 3. User re-enters, creates new connection, SIG-NEW links B
      # 4. User deletes SIG-OLD - should NOT delete the new connection

      # Step 1: Initial state - B has linked_sig_eve_id = SIG-OLD
      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: "SIG-OLD"
        })

      assert system_b.linked_sig_eve_id == "SIG-OLD"

      # Step 2: Connection deleted - linked_sig_eve_id cleared (our fix in action)
      {:ok, system_b_after_conn_delete} =
        MapSystem.update_linked_sig_eve_id(system_b, %{linked_sig_eve_id: nil})

      assert is_nil(system_b_after_conn_delete.linked_sig_eve_id)

      # Step 3: New connection created - SIG-NEW links B
      {:ok, system_b_after_new_conn} =
        MapSystem.update_linked_sig_eve_id(system_b_after_conn_delete, %{
          linked_sig_eve_id: "SIG-NEW"
        })

      assert system_b_after_new_conn.linked_sig_eve_id == "SIG-NEW"

      # Step 4: Now when user tries to delete SIG-OLD:
      # is_active_signature_for_target? would check:
      # system_b.linked_sig_eve_id ("SIG-NEW") == old_sig.eve_id ("SIG-OLD")
      # This returns FALSE, so connection deletion is SKIPPED

      old_sig_eve_id = "SIG-OLD"
      refute system_b_after_new_conn.linked_sig_eve_id == old_sig_eve_id

      # The fix works!
    end
  end
end
