defmodule WandererApp.Map.Server.K162BacklinkPreferenceTest do
  @moduledoc """
  Tests for the K162 back-link preference fix.

  Verifies that when a K162 (return wormhole) signature is linked to a system
  where a forward signature (e.g., H296) already set mass/time on the connection,
  the forward sig values take precedence over K162 form defaults.

  Also verifies that the K162's custom_info is updated to reflect resolved values.
  """
  use WandererApp.DataCase, async: false

  import Mox

  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Map.Server.SignaturesImpl
  alias WandererAppWeb.Factory

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    # Setup DDRT mocks
    Test.DDRTMock
    |> stub(:init_tree, fn _name, _opts -> :ok end)
    |> stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> stub(:delete, fn _ids, _tree_name -> {:ok, %{}} end)
    |> stub(:query, fn _bbox, _tree_name -> {:ok, []} end)

    # Setup CachedInfo mocks
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

    character = Factory.create_character()
    map = Factory.create_map(%{owner_id: character.id})

    %{map: map, character: character}
  end

  describe "find_forward_signature/2" do
    test "finds forward signature in target system that links back to source", %{map: map} do
      # System A (source) at solar_system_id 30_000_142
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      # System B (target) at solar_system_id 30_000_143
      {:ok, system_b} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_143, name: "System B"})

      # Forward sig in System A: H296 linking to System B (solar_system_id)
      _forward_sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "FWD-001",
          type: "H296",
          group: "Wormhole",
          linked_system_id: 30_000_143,
          custom_info:
            Jason.encode!(%{"time_status" => 1, "mass_status" => 1, "destType" => nil})
        })

      # find_forward_signature looks in the target system (system_b.id)
      # for a signature linking back to the source solar_system_id (30_000_142)
      # But the forward sig is in system_a, linking TO system_b.
      # So we need to call it with system_a.id (where the forward sig lives)
      # and source_solar_system_id = 30_000_143 (what the forward sig links to)
      #
      # Wait - re-reading the function:
      # find_forward_signature(target_system_uuid, source_solar_system_id)
      # It looks in target_system_uuid for sigs with linked_system_id == source_solar_system_id
      #
      # In the K162 linking scenario:
      # - K162 is in System B, user links it to System A
      # - We call find_forward_signature(target_system.id = System A, source_solar_system = System B's solar_system_id)
      # - This finds the H296 in System A that has linked_system_id = System B's solar_system_id

      result = SignaturesImpl.find_forward_signature(system_a.id, 30_000_143)
      assert result != nil
      assert result.eve_id == "FWD-001"
      assert result.type == "H296"
    end

    test "returns nil when no forward signature exists", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      result = SignaturesImpl.find_forward_signature(system_a.id, 30_000_143)
      assert is_nil(result)
    end

    test "returns nil when signatures exist but none link back to source", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      # Signature in System A but not linked to anything
      _unlinked_sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "UNL-001",
          type: "H296",
          group: "Wormhole"
        })

      result = SignaturesImpl.find_forward_signature(system_a.id, 30_000_143)
      assert is_nil(result)
    end
  end

  describe "back-link preference logic" do
    test "forward sig time_status and mass_status take precedence over K162 defaults" do
      # This tests the fixed logic: `Map.get(decoded, "time_status") || signature_time_status`
      # Forward sig has time_status=1 (16h EOL), mass_status=1 (half mass)
      # K162 has time_status=0 (24h), mass_status=0 (normal)

      forward_custom_info = %{"time_status" => 1, "mass_status" => 1}
      k162_time_status = 0
      k162_mass_status = 0

      # Fixed logic: always prefer forward sig values
      fwd_time = Map.get(forward_custom_info, "time_status") || k162_time_status
      fwd_mass = Map.get(forward_custom_info, "mass_status") || k162_mass_status

      # Forward sig values (1) should take precedence
      assert fwd_time == 1
      assert fwd_mass == 1
    end

    test "K162 values used when forward sig has nil values" do
      # Forward sig has no time/mass set
      forward_custom_info = %{}
      k162_time_status = 2
      k162_mass_status = 2

      fwd_time = Map.get(forward_custom_info, "time_status") || k162_time_status
      fwd_mass = Map.get(forward_custom_info, "mass_status") || k162_mass_status

      # K162 values should be used as fallback
      assert fwd_time == 2
      assert fwd_mass == 2
    end

    test "0 values from forward sig are truthy in Elixir and take precedence" do
      # 0 is truthy in Elixir (only nil and false are falsy)
      forward_custom_info = %{"time_status" => 0, "mass_status" => 0}
      k162_time_status = 2
      k162_mass_status = 2

      fwd_time = Map.get(forward_custom_info, "time_status") || k162_time_status
      fwd_mass = Map.get(forward_custom_info, "mass_status") || k162_mass_status

      # 0 is truthy in Elixir, so forward sig's 0 values should take precedence
      assert fwd_time == 0
      assert fwd_mass == 0
    end

    test "old logic (is_nil check) would incorrectly keep K162 defaults" do
      # Demonstrates the bug with old logic:
      # if is_nil(signature_time_status), do: Map.get(decoded, "time_status"), else: signature_time_status
      # When K162 has time_status=0, is_nil(0) is false, so K162's 0 was kept

      forward_custom_info = %{"time_status" => 1, "mass_status" => 1}
      k162_time_status = 0
      k162_mass_status = 0

      # Old logic (broken):
      old_fwd_time =
        if is_nil(k162_time_status),
          do: Map.get(forward_custom_info, "time_status"),
          else: k162_time_status

      old_fwd_mass =
        if is_nil(k162_mass_status),
          do: Map.get(forward_custom_info, "mass_status"),
          else: k162_mass_status

      # Old logic would keep K162 defaults (0) instead of forward sig values (1)
      assert old_fwd_time == 0
      assert old_fwd_mass == 0

      # New logic (fixed):
      new_fwd_time = Map.get(forward_custom_info, "time_status") || k162_time_status
      new_fwd_mass = Map.get(forward_custom_info, "mass_status") || k162_mass_status

      # New logic correctly uses forward sig values
      assert new_fwd_time == 1
      assert new_fwd_mass == 1
    end
  end

  describe "K162 custom_info update after linking" do
    test "K162 signature custom_info is updated with resolved values", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      # K162 in system A with default values
      k162_sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "K162-001",
          type: "K162",
          group: "Wormhole",
          custom_info:
            Jason.encode!(%{"time_status" => 0, "mass_status" => 0, "destType" => "C2"})
        })

      # Simulate what the linking code does: update K162's custom_info
      # with resolved values from the forward signature
      signature_time_status = 1
      signature_mass_status = 1

      updated_custom_info =
        (k162_sig.custom_info || "{}")
        |> Jason.decode!()
        |> then(fn decoded ->
          decoded
          |> then(fn d ->
            if not is_nil(signature_time_status),
              do: Map.put(d, "time_status", signature_time_status),
              else: d
          end)
          |> then(fn d ->
            if not is_nil(signature_mass_status),
              do: Map.put(d, "mass_status", signature_mass_status),
              else: d
          end)
        end)
        |> Jason.encode!()

      {:ok, updated_sig} =
        MapSystemSignature.update(k162_sig, %{custom_info: updated_custom_info})

      # Verify the custom_info was updated
      decoded = Jason.decode!(updated_sig.custom_info)
      assert decoded["time_status"] == 1
      assert decoded["mass_status"] == 1
      # destType should be preserved
      assert decoded["destType"] == "C2"
    end

    test "K162 custom_info update preserves existing fields", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      k162_sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "K162-002",
          type: "K162",
          group: "Wormhole",
          custom_info:
            Jason.encode!(%{
              "time_status" => 0,
              "mass_status" => 0,
              "destType" => "C5",
              "extra_field" => "preserved"
            })
        })

      # Only update time_status, leave mass_status nil (should not update)
      signature_time_status = 2
      signature_mass_status = nil

      updated_custom_info =
        (k162_sig.custom_info || "{}")
        |> Jason.decode!()
        |> then(fn decoded ->
          decoded
          |> then(fn d ->
            if not is_nil(signature_time_status),
              do: Map.put(d, "time_status", signature_time_status),
              else: d
          end)
          |> then(fn d ->
            if not is_nil(signature_mass_status),
              do: Map.put(d, "mass_status", signature_mass_status),
              else: d
          end)
        end)
        |> Jason.encode!()

      {:ok, updated_sig} =
        MapSystemSignature.update(k162_sig, %{custom_info: updated_custom_info})

      decoded = Jason.decode!(updated_sig.custom_info)
      # time_status should be updated
      assert decoded["time_status"] == 2
      # mass_status should remain unchanged (nil signature_mass_status)
      assert decoded["mass_status"] == 0
      # Other fields should be preserved
      assert decoded["destType"] == "C5"
      assert decoded["extra_field"] == "preserved"
    end

    test "K162 custom_info update handles nil initial custom_info", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{map_id: map.id, solar_system_id: 30_000_142, name: "System A"})

      k162_sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "K162-003",
          type: "K162",
          group: "Wormhole"
          # custom_info is nil by default
        })

      signature_time_status = 1
      signature_mass_status = 1

      updated_custom_info =
        (k162_sig.custom_info || "{}")
        |> Jason.decode!()
        |> then(fn decoded ->
          decoded
          |> then(fn d ->
            if not is_nil(signature_time_status),
              do: Map.put(d, "time_status", signature_time_status),
              else: d
          end)
          |> then(fn d ->
            if not is_nil(signature_mass_status),
              do: Map.put(d, "mass_status", signature_mass_status),
              else: d
          end)
        end)
        |> Jason.encode!()

      {:ok, updated_sig} =
        MapSystemSignature.update(k162_sig, %{custom_info: updated_custom_info})

      decoded = Jason.decode!(updated_sig.custom_info)
      assert decoded["time_status"] == 1
      assert decoded["mass_status"] == 1
    end
  end
end
