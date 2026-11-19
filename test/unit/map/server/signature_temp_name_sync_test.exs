defmodule WandererApp.Map.Server.SignatureTempNameSyncTest do
  @moduledoc """
  Tests for syncing a system's tag/labels to the linked signature's temporary name.
  """
  use WandererApp.DataCase, async: false

  import Mox

  alias WandererApp.Api.MapSystem
  alias WandererApp.Api.MapSystemSignature
  alias WandererAppWeb.Factory

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    Test.DDRTMock
    |> stub(:init_tree, fn _name, _opts -> :ok end)
    |> stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> stub(:delete, fn _ids, _tree_name -> {:ok, %{}} end)
    |> stub(:query, fn _bbox, _tree_name -> {:ok, []} end)

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

      30_000_144 ->
        {:ok,
         %{
           solar_system_id: 30_000_144,
           solar_system_name: "Urlen",
           system_class: 4,
           security: "-0.9"
         }}

      30_000_145 ->
        {:ok,
         %{
           solar_system_id: 30_000_145,
           solar_system_name: "Maurasi",
           system_class: 3,
           security: "-0.9"
         }}

      _ ->
        {:error, :not_found}
    end)

    character = Factory.create_character()
    map = Factory.create_map(%{owner_id: character.id})

    %{map: map, character: character}
  end

  describe "signature temporary_name sync" do
    test "correctly syncs tag to signature temporary_name", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter"
        })

      sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-123",
          name: "XYZ",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      # Mock map_cache for update_system_by_solar_system_id/2
      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      # Call SystemsImpl directly to trigger update_system_tag
      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: system_b.solar_system_id,
          tag: "A2"
        })

      updated_sig = MapSystemSignature.by_id!(sig.id)
      assert updated_sig.temporary_name == "A2"
    end

    test "correctly syncs labels to signature temporary_name", %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter"
        })

      sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-456",
          name: "XYZ",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      # Mock map_cache for update_system_by_solar_system_id/2
      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      # Update system labels (JSON formatted)
      labels_json = Jason.encode!(%{"customLabel" => "B1"})

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_labels(map.id, %{
          solar_system_id: system_b.solar_system_id,
          labels: labels_json
        })

      updated_sig = MapSystemSignature.by_id!(sig.id)
      assert updated_sig.temporary_name == "B1"
    end

    test "does not sync to signatures on a different map", %{map: map, character: character} do
      map_other = Factory.create_map(%{owner_id: character.id})

      {:ok, system_a_other} =
        MapSystem.create(%{
          map_id: map_other.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter"
        })

      sig_other =
        Factory.insert(:map_system_signature, %{
          system_id: system_a_other.id,
          eve_id: "SIG-OTHER",
          name: "XYZ",
          temporary_name: "ORIGINAL",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: system_b.solar_system_id,
          tag: "NEW_TAG"
        })

      unchanged_sig = MapSystemSignature.by_id!(sig_other.id)
      assert unchanged_sig.temporary_name == "ORIGINAL"
    end

    test "syncs system temporary_name when tag and customLabel are empty, and ignores status badge labels",
         %{
           map: map
         } do
      {:ok, system_a} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: "SIG-FWD"
        })

      sig_fwd =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-FWD",
          name: "XYZ",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      sig_return =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-RET",
          name: "RET",
          temporary_name: "<",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_temporary_name(map.id, %{
          solar_system_id: system_b.solar_system_id,
          temporary_name: "A1"
        })

      assert MapSystemSignature.by_id!(sig_fwd.id).temporary_name == "A1"
      # Return hole signature should not be overwritten because linked_sig_eve_id is SIG-FWD
      assert MapSystemSignature.by_id!(sig_return.id).temporary_name == "<"

      # Adding a status badge with empty customLabel should not overwrite A1 with "clear"
      labels_json = Jason.encode!(%{"customLabel" => "", "labels" => ["clear"]})

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_labels(map.id, %{
          solar_system_id: system_b.solar_system_id,
          labels: labels_json
        })

      assert MapSystemSignature.by_id!(sig_fwd.id).temporary_name == "A1"
    end

    test "does not overwrite return-hole signature pointing to root/Home system when Home has no linked_sig_eve_id",
         %{map: map} do
      {:ok, home_system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, child_system} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          linked_sig_eve_id: "SIG-HOME-TO-CHILD"
        })

      _sig_fwd =
        Factory.insert(:map_system_signature, %{
          system_id: home_system.id,
          eve_id: "SIG-HOME-TO-CHILD",
          name: "FWD",
          temporary_name: "A",
          group: "Wormhole",
          linked_system_id: child_system.solar_system_id
        })

      sig_return_to_home =
        Factory.insert(:map_system_signature, %{
          system_id: child_system.id,
          eve_id: "SIG-CHILD-TO-HOME",
          name: "K162",
          temporary_name: "<",
          group: "Wormhole",
          linked_system_id: home_system.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home_system.solar_system_id => %{
            solar_system_id: home_system.solar_system_id
          }
        }
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: home_system.solar_system_id,
          tag: "HQ"
        })

      assert MapSystemSignature.by_id!(sig_return_to_home.id).temporary_name == "<"
    end

    test "clearing a system's tag clears linked signature temporary_name instead of reverting to stale system temporary_name",
         %{map: map} do
      {:ok, system_a} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          tag: "B",
          temporary_name: "A",
          linked_sig_eve_id: "SIG-LINKED"
        })

      sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-LINKED",
          name: "XYZ",
          temporary_name: "B",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: system_b.solar_system_id,
          tag: nil
        })

      assert MapSystemSignature.by_id!(sig.id).temporary_name == nil
    end

    test "updating system temporary_name syncs the new temporary_name even when system has a tag",
         %{
           map: map
         } do
      {:ok, system_a} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      {:ok, system_b} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Perimeter",
          tag: "A",
          linked_sig_eve_id: "SIG-LINKED-2"
        })

      sig =
        Factory.insert(:map_system_signature, %{
          system_id: system_a.id,
          eve_id: "SIG-LINKED-2",
          name: "XYZ",
          temporary_name: "A",
          group: "Wormhole",
          linked_system_id: system_b.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          system_b.solar_system_id => %{
            solar_system_id: system_b.solar_system_id
          }
        }
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_temporary_name(map.id, %{
          solar_system_id: system_b.solar_system_id,
          temporary_name: "CUSTOM"
        })

      assert MapSystemSignature.by_id!(sig.id).temporary_name == "CUSTOM"
    end

    test "full multi-hop chain backend workflow: linking forward/return holes, K162 inheritance on intermediate hops, re-linking, stale linked_sig_eve_id recovery, and tag/label renames",
         %{
           map: map
         } do
      {:ok, home} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Home"
        })

      {:ok, hop1} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Hop1",
          linked_sig_eve_id: "STALE-DELETED-SIG"
        })

      {:ok, hop2} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_144,
          name: "Hop2"
        })

      {:ok, hop1_replacement} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_145,
          name: "Hop1_Replacement"
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => home,
          hop1.solar_system_id => hop1,
          hop2.solar_system_id => hop2,
          hop1_replacement.solar_system_id => hop1_replacement
        },
        connections: %{}
      })

      sig_home_to_hop1 =
        Factory.insert(:map_system_signature, %{
          system_id: home.id,
          eve_id: "FWD-H-1",
          name: "Unstable Wormhole",
          type: "C247",
          temporary_name: "1",
          group: "Wormhole",
          custom_info: Jason.encode!(%{"time_status" => 1, "mass_status" => 0})
        })

      conn = %{assigns: %{map_id: map.id}}

      # 1. Link FWD-H-1 from Home -> Hop1.
      # Even though Hop1 had a stale linked_sig_eve_id ("STALE-DELETED-SIG"), no active signature has that eve_id,
      # so Hop1 must update linked_sig_eve_id to "FWD-H-1" and temporary_name to "1".
      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_home_to_hop1.id,
          %{"solar_system_target" => hop1.solar_system_id}
        )

      hop1_reloaded = MapSystem.by_id!(hop1.id)
      assert hop1_reloaded.linked_sig_eve_id == "FWD-H-1"
      assert hop1_reloaded.temporary_name == "1"

      # Refresh map_cache with updated hop1
      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => home,
          hop1.solar_system_id => hop1_reloaded,
          hop2.solar_system_id => hop2,
          hop1_replacement.solar_system_id => hop1_replacement
        },
        connections: %{}
      })

      # 2. Link forward sig FWD-1-2 from Hop1 -> Hop2 (with EOL time_status=1 and crit mass_status=2)
      sig_hop1_to_hop2 =
        Factory.insert(:map_system_signature, %{
          system_id: hop1.id,
          eve_id: "FWD-1-2",
          name: "Unstable Wormhole",
          type: "X877",
          temporary_name: "1.1",
          group: "Wormhole",
          custom_info: Jason.encode!(%{"time_status" => 1, "mass_status" => 2})
        })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_hop1_to_hop2.id,
          %{"solar_system_target" => hop2.solar_system_id}
        )

      hop2_reloaded = MapSystem.by_id!(hop2.id)
      assert hop2_reloaded.linked_sig_eve_id == "FWD-1-2"
      assert hop2_reloaded.temporary_name == "1.1"

      # 3. Link return hole K162 (RET-2-1) from Hop2 back to Hop1 (which ALREADY has linked_sig_eve_id == "FWD-H-1"!).
      # Must NOT overwrite Hop1's linked_sig_eve_id or temporary_name, AND must inherit
      # time_status=1 and mass_status=2 from FWD-1-2!
      sig_hop2_return_to_hop1 =
        Factory.insert(:map_system_signature, %{
          system_id: hop2.id,
          eve_id: "RET-2-1",
          name: "K162",
          type: "K162",
          temporary_name: "<",
          group: "Wormhole",
          custom_info: Jason.encode!(%{})
        })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_hop2_return_to_hop1.id,
          %{"solar_system_target" => hop1.solar_system_id}
        )

      hop1_after_return = MapSystem.by_id!(hop1.id)
      assert hop1_after_return.linked_sig_eve_id == "FWD-H-1"
      assert hop1_after_return.temporary_name == "1"

      ret_sig_reloaded = MapSystemSignature.by_id!(sig_hop2_return_to_hop1.id)
      assert ret_sig_reloaded.temporary_name == "<"
      ret_custom_info = Jason.decode!(ret_sig_reloaded.custom_info)
      assert ret_custom_info["time_status"] == 1
      assert ret_custom_info["mass_status"] == 2

      # 4. Rename Hop1's tag to "B": must sync "B" to FWD-H-1 in Home, while leaving RET-2-1 ("<") in Hop2 untouched!
      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: hop1.solar_system_id,
          tag: "B"
        })

      assert MapSystemSignature.by_id!(sig_home_to_hop1.id).temporary_name == "B"
      assert MapSystemSignature.by_id!(sig_hop2_return_to_hop1.id).temporary_name == "<"

      # 5. Re-link FWD-H-1 directly from Hop1 to Hop1_Replacement:
      # Must clear Hop1.linked_sig_eve_id and set Hop1_Replacement.linked_sig_eve_id = "FWD-H-1"
      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => home,
          hop1.solar_system_id => MapSystem.by_id!(hop1.id),
          hop2.solar_system_id => hop2_reloaded,
          hop1_replacement.solar_system_id => hop1_replacement
        },
        connections: %{}
      })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_home_to_hop1.id,
          %{"solar_system_target" => hop1_replacement.solar_system_id}
        )

      assert MapSystem.by_id!(hop1.id).linked_sig_eve_id == nil
      assert MapSystem.by_id!(hop1_replacement.id).linked_sig_eve_id == "FWD-H-1"
    end

    test "mixed unpasted/pasted chain and SystemSettingsDialog rename: linking return hole to unpasted Home does not clobber Home, and unchanged temporary_name does not clobber customLabel rename",
         %{
           map: map
         } do
      {:ok, home} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Home"
        })

      {:ok, hop1_unpasted_from_home} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_143,
          name: "Hop1"
        })

      {:ok, hop2} =
        MapSystem.create(%{
          map_id: map.id,
          solar_system_id: 30_000_144,
          name: "Hop2"
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => home,
          hop1_unpasted_from_home.solar_system_id => hop1_unpasted_from_home,
          hop2.solar_system_id => hop2
        },
        connections: %{}
      })

      conn = %{assigns: %{map_id: map.id}}

      # 1. Player jumped Home -> Hop1 WITHOUT pasting any signatures in Home!
      # In Hop1, player pastes return hole RET-101 ("<") and links it back to Home.
      # Even though Home has no forward_sig and linked_sig_eve_id is nil, Home must NOT
      # get linked_sig_eve_id="RET-101" or temporary_name="<"!
      sig_ret_to_unpasted_home =
        Factory.insert(:map_system_signature, %{
          system_id: hop1_unpasted_from_home.id,
          eve_id: "RET-101",
          name: "K162",
          type: "K162",
          temporary_name: "<",
          group: "Wormhole",
          custom_info:
            Jason.encode!(%{
              "bookmark_index_chained" => "<",
              "bookmark_index_chained_letters" => "<"
            })
        })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_ret_to_unpasted_home.id,
          %{"solar_system_target" => home.solar_system_id}
        )

      home_reloaded = MapSystem.by_id!(home.id)
      assert home_reloaded.linked_sig_eve_id == nil
      assert home_reloaded.temporary_name == nil

      # 2. Renaming Home's tag to "HQ" must NOT overwrite RET-101's "<" temporary_name
      # even though Home has no forward_sig!
      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: home.solar_system_id,
          tag: "HQ"
        })

      assert MapSystemSignature.by_id!(sig_ret_to_unpasted_home.id).temporary_name == "<"

      # 3. Link forward hole FWD-102 from Hop1 -> Hop2 (auto-setting Hop2.temporary_name = "1.1" and Hop2.tag = "1.1")
      sig_fwd_to_hop2 =
        Factory.insert(:map_system_signature, %{
          system_id: hop1_unpasted_from_home.id,
          eve_id: "FWD-102",
          name: "Unstable Wormhole",
          type: "C247",
          temporary_name: "1.1",
          group: "Wormhole",
          custom_info:
            Jason.encode!(%{
              "bookmark_index" => 1,
              "bookmark_index_chained" => "1.1",
              "bookmark_index_chained_letters" => "A.1"
            })
        })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_fwd_to_hop2.id,
          %{"solar_system_target" => hop2.solar_system_id}
        )

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: hop2.solar_system_id,
          tag: "1.1"
        })

      hop2_linked = MapSystem.by_id!(hop2.id)
      assert hop2_linked.linked_sig_eve_id == "FWD-102"
      assert hop2_linked.temporary_name == "1.1"
      assert hop2_linked.tag == "1.1"

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => hop1_unpasted_from_home,
          hop2.solar_system_id => hop2_linked
        },
        connections: %{}
      })

      # 4. Simulate SystemSettingsDialog save on Hop2:
      # Sends update_system_labels (customLabel: "7") followed immediately by
      # update_system_temporary_name (unchanged "1.1").
      # FWD-102's temporary_name must become "7" and NOT be overwritten back to "1.1"!
      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_labels(map.id, %{
          solar_system_id: hop2.solar_system_id,
          labels: Jason.encode!(%{"customLabel" => "7", "labels" => []})
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => hop1_unpasted_from_home,
          hop2.solar_system_id => MapSystem.by_id!(hop2.id)
        },
        connections: %{}
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_temporary_name(map.id, %{
          solar_system_id: hop2.solar_system_id,
          temporary_name: "1.1"
        })

      assert MapSystemSignature.by_id!(sig_fwd_to_hop2.id).temporary_name == "7"

      # Clearing temporary_name to "" in SystemSettingsDialog while customLabel "7" is set
      # must fall back to "7" (not nil)!
      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_temporary_name(map.id, %{
          solar_system_id: hop2.solar_system_id,
          temporary_name: ""
        })

      assert MapSystemSignature.by_id!(sig_fwd_to_hop2.id).temporary_name == "7"

      # 5. Now rename Hop2's tag to "9" via the Tag context menu while customLabel "7" is still set:
      # Because tag was explicitly changed, FWD-102's temporary_name must sync to the new tag "9"!
      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => hop1_unpasted_from_home,
          hop2.solar_system_id => MapSystem.by_id!(hop2.id)
        },
        connections: %{}
      })

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: hop2.solar_system_id,
          tag: "9"
        })

      assert MapSystemSignature.by_id!(sig_fwd_to_hop2.id).temporary_name == "9"

      # 6. Re-link FWD-102 from Hop2 to a new Hop3 system:
      # Hop2 must have BOTH linked_sig_eve_id AND temporary_name cleared to nil!
      hop3 =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 31_000_013,
          name: "J100013",
          temporary_name: nil
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => hop1_unpasted_from_home,
          hop2.solar_system_id => MapSystem.by_id!(hop2.id),
          hop3.solar_system_id => hop3
        },
        connections: %{}
      })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_fwd_to_hop2.id,
          %{"solar_system_target" => hop3.solar_system_id}
        )

      hop2_after_relink = MapSystem.by_id!(hop2.id)
      assert hop2_after_relink.linked_sig_eve_id == nil
      assert hop2_after_relink.temporary_name == nil

      hop3_after_relink = MapSystem.by_id!(hop3.id)
      assert hop3_after_relink.linked_sig_eve_id == "FWD-102"
      assert hop3_after_relink.temporary_name == "9"
      assert MapSystemSignature.by_id!(sig_fwd_to_hop2.id).temporary_name == "9"

      # 7. Return hole with empty bookmark_return_hole_symbol (""):
      # custom_info has bookmark_index_chained: "" and bookmark_index: nil, temporary_name: nil.
      # Linking back to unpasted hop1_unpasted_from_home must NOT set linked_sig_eve_id,
      # and renaming hop1_unpasted_from_home must NOT overwrite the return hole's temporary_name!
      sig_empty_symbol_ret =
        Factory.insert(:map_system_signature, %{
          system_id: hop3.id,
          eve_id: "RET-201",
          name: "K162",
          type: "K162",
          temporary_name: nil,
          group: "Wormhole",
          custom_info:
            Jason.encode!(%{
              "bookmark_index_chained" => "",
              "bookmark_index_chained_letters" => ""
            })
        })

      {:ok, _} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_empty_symbol_ret.id,
          %{"solar_system_target" => hop1_unpasted_from_home.solar_system_id}
        )

      hop1_reloaded = MapSystem.by_id!(hop1_unpasted_from_home.id)
      assert hop1_reloaded.linked_sig_eve_id == nil

      :ok =
        WandererApp.Map.Server.SystemsImpl.update_system_tag(map.id, %{
          solar_system_id: hop1_unpasted_from_home.solar_system_id,
          tag: "1"
        })

      assert MapSystemSignature.by_id!(sig_empty_symbol_ret.id).temporary_name == nil

      # 8. Deleting a child system (hop3) that has a return-hole signature linked to its parent (hop1)
      # must NOT wipe the parent's linked_sig_eve_id (which points to Home's forward signature)!
      {:ok, hop1_with_parent_sig} =
        WandererApp.MapSystemRepo.update_linked_sig_eve_id(hop1_reloaded, %{
          linked_sig_eve_id: "HOME-TO-HOP1"
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => hop1_with_parent_sig,
          hop2.solar_system_id => MapSystem.by_id!(hop2.id),
          hop3.solar_system_id => MapSystem.by_id!(hop3.id)
        },
        connections: %{}
      })

      WandererApp.Map.Server.SystemsImpl.delete_systems(
        map.id,
        [hop3.solar_system_id],
        nil,
        nil
      )

      hop1_after_child_delete = MapSystem.by_id!(hop1_unpasted_from_home.id)
      assert hop1_after_child_delete.linked_sig_eve_id == "HOME-TO-HOP1"

      # And hop2's forward signature (FWD-102) that pointed to deleted hop3 must be unlinked,
      # while preserving its temporary_name ("9")!
      fwd_102_after_child_delete = MapSystemSignature.by_id!(sig_fwd_to_hop2.id)
      assert fwd_102_after_child_delete.linked_system_id == nil
      assert fwd_102_after_child_delete.temporary_name == "9"

      # 9. Unlinking primary signature from a target system when a secondary signature also links to that target
      # must NOT wipe the secondary signature's temporary_name!
      {:ok, hop2_primary} =
        hop2.id
        |> MapSystem.by_id!()
        |> WandererApp.MapSystemRepo.update_linked_sig_eve_id(%{linked_sig_eve_id: "PRI-200"})
        |> elem(1)
        |> WandererApp.MapSystemRepo.update_temporary_name(%{temporary_name: "1.1"})

      sig_primary =
        Factory.insert(:map_system_signature, %{
          system_id: hop1_unpasted_from_home.id,
          eve_id: "PRI-200",
          name: "Unstable Wormhole",
          type: "C247",
          temporary_name: "1.1",
          group: "Wormhole",
          linked_system_id: hop2_primary.solar_system_id
        })

      sig_secondary =
        Factory.insert(:map_system_signature, %{
          system_id: hop1_unpasted_from_home.id,
          eve_id: "SEC-201",
          name: "Unstable Wormhole",
          type: "C247",
          temporary_name: "1.2",
          group: "Wormhole",
          linked_system_id: hop2_primary.solar_system_id
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => MapSystem.by_id!(hop1_unpasted_from_home.id),
          hop2_primary.solar_system_id => hop2_primary
        },
        connections: %{}
      })

      {:ok, _} = WandererApp.Map.Operations.Signatures.unlink_signature(conn, sig_primary.id)

      assert MapSystemSignature.by_id!(sig_primary.id).temporary_name == "1.1"
      assert MapSystemSignature.by_id!(sig_secondary.id).temporary_name == "1.2"

      # 10. Linking a forward signature with temporary_name: nil (e.g. when bookmark_auto_temp_name is disabled
      # and system_auto_tag set target_system.tag = "1.2") to a target system must sync target_system's tag/label
      # back to signature.temporary_name; and re-linking that signature after clearing its temporary_name to nil
      # must clear target_system.temporary_name without overwriting signature.temporary_name back to "1.2"!
      {:ok, hop2_tagged} =
        hop2.id
        |> MapSystem.by_id!()
        |> WandererApp.MapSystemRepo.update_linked_sig_eve_id(%{linked_sig_eve_id: nil})
        |> elem(1)
        |> WandererApp.MapSystemRepo.update_temporary_name(%{temporary_name: nil})
        |> elem(1)
        |> WandererApp.MapSystemRepo.update_tag(%{tag: "1.2"})
        |> elem(1)
        |> WandererApp.MapSystemRepo.update_labels(%{
          labels: Jason.encode!(%{"customLabel" => "", "labels" => []})
        })

      sig_no_temp =
        Factory.insert(:map_system_signature, %{
          system_id: hop1_unpasted_from_home.id,
          eve_id: "NOTEMP-300",
          name: "Unstable Wormhole",
          type: "C247",
          temporary_name: nil,
          group: "Wormhole",
          custom_info: Jason.encode!(%{"bookmark_index" => 2, "bookmark_index_chained" => "1.2"})
        })

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => MapSystem.by_id!(hop1_unpasted_from_home.id),
          hop2_tagged.solar_system_id => hop2_tagged
        },
        connections: %{}
      })

      {:ok, linked_no_temp} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_no_temp.id,
          %{"solar_system_target" => hop2_tagged.solar_system_id}
        )

      assert linked_no_temp.temporary_name == "1.2"
      assert MapSystemSignature.by_id!(sig_no_temp.id).temporary_name == "1.2"

      # Now user clears NOTEMP-300's temporary_name to nil while hop2_tagged has temporary_name: "1.2" and tag: "1.2",
      # and saves/re-links to the same target system:
      {:ok, hop2_with_temp} =
        hop2_tagged.id
        |> MapSystem.by_id!()
        |> WandererApp.MapSystemRepo.update_temporary_name(%{temporary_name: "1.2"})

      {:ok, _} =
        sig_no_temp.id
        |> MapSystemSignature.by_id!()
        |> MapSystemSignature.update(%{temporary_name: nil})

      Cachex.put(:map_cache, map.id, %{
        systems: %{
          home.solar_system_id => MapSystem.by_id!(home.id),
          hop1_unpasted_from_home.solar_system_id => MapSystem.by_id!(hop1_unpasted_from_home.id),
          hop2_with_temp.solar_system_id => hop2_with_temp
        },
        connections: %{}
      })

      {:ok, relinked_cleared} =
        WandererApp.Map.Operations.Signatures.link_signature(
          conn,
          sig_no_temp.id,
          %{"solar_system_target" => hop2_with_temp.solar_system_id}
        )

      assert relinked_cleared.temporary_name == nil
      assert MapSystemSignature.by_id!(sig_no_temp.id).temporary_name == nil
      assert MapSystem.by_id!(hop2_with_temp.id).temporary_name == nil
    end
  end
end
