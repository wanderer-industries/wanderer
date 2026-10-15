defmodule WandererApp.Map.GarbageCollectorTest do
  use WandererApp.DataCase, async: false

  import WandererApp.EnvHelper

  alias WandererApp.Api.{MapChainPassages, MapSystemSignature}
  alias WandererApp.Map.GarbageCollector

  @seconds_per_day 24 * 60 * 60

  setup do
    map = insert(:map)
    system = insert(:map_system, %{map_id: map.id})
    %{map: map, system: system, character: insert(:character)}
  end

  describe "cleanup_chain_passages/0" do
    test "deletes passages older than the configured retention and keeps newer ones", ctx do
      old = create_passage(ctx, age_days: 10)
      fresh = create_passage(ctx, age_days: 3)

      with_env_override(:map_chain_passages_retention_days, 7) do
        assert :ok = GarbageCollector.cleanup_chain_passages()
      end

      remaining_ids = remaining_passage_ids()
      refute old.id in remaining_ids
      assert fresh.id in remaining_ids
    end

    test "a longer retention keeps passages the default window would delete", ctx do
      passage = create_passage(ctx, age_days: 20)

      with_env_override(:map_chain_passages_retention_days, 30) do
        assert :ok = GarbageCollector.cleanup_chain_passages()
      end

      assert passage.id in remaining_passage_ids()
    end

    test "falls back to the 7 day default when retention is not configured", ctx do
      old = create_passage(ctx, age_days: 8)
      fresh = create_passage(ctx, age_days: 6)

      without_env(:map_chain_passages_retention_days, fn ->
        assert :ok = GarbageCollector.cleanup_chain_passages()
      end)

      remaining_ids = remaining_passage_ids()
      refute old.id in remaining_ids
      assert fresh.id in remaining_ids
    end
  end

  describe "cleanup_system_signatures/0" do
    test "deletes signatures older than the configured retention and keeps newer ones", ctx do
      old = create_signature(ctx, age_days: 20)
      fresh = create_signature(ctx, age_days: 5)

      with_env_override(:map_system_signatures_retention_days, 14) do
        assert :ok = GarbageCollector.cleanup_system_signatures()
      end

      remaining_ids = remaining_signature_ids(ctx)
      refute old.id in remaining_ids
      assert fresh.id in remaining_ids
    end

    test "a longer retention keeps signatures the default window would delete", ctx do
      signature = create_signature(ctx, age_days: 20)

      with_env_override(:map_system_signatures_retention_days, 30) do
        assert :ok = GarbageCollector.cleanup_system_signatures()
      end

      assert signature.id in remaining_signature_ids(ctx)
    end

    test "falls back to the 14 day default when retention is not configured", ctx do
      old = create_signature(ctx, age_days: 15)
      fresh = create_signature(ctx, age_days: 13)

      without_env(:map_system_signatures_retention_days, fn ->
        assert :ok = GarbageCollector.cleanup_system_signatures()
      end)

      remaining_ids = remaining_signature_ids(ctx)
      refute old.id in remaining_ids
      assert fresh.id in remaining_ids
    end
  end

  # Runs `fun` with the key absent from the application env, then restores
  # the previous state (re-deleting it if it was absent before).
  defp without_env(key, fun) do
    original = Application.fetch_env(:wanderer_app, key)
    Application.delete_env(:wanderer_app, key)

    try do
      fun.()
    after
      case original do
        {:ok, value} -> Application.put_env(:wanderer_app, key, value)
        :error -> Application.delete_env(:wanderer_app, key)
      end
    end
  end

  defp create_signature(%{system: system}, age_days: age_days) do
    signature = insert(:map_system_signature, %{system_id: system.id})
    backdate(MapSystemSignature, signature.id, age_days)
    signature
  end

  defp remaining_signature_ids(%{system: system}) do
    {:ok, signatures} = MapSystemSignature.by_system_id_all(system.id)
    Enum.map(signatures, & &1.id)
  end

  defp create_passage(%{map: map, character: character}, age_days: age_days) do
    {:ok, passage} =
      MapChainPassages.new(%{
        map_id: map.id,
        character_id: character.id,
        ship_type_id: 587,
        ship_name: "Rifter",
        solar_system_source_id: 30_000_142,
        solar_system_target_id: 30_000_144
      })

    backdate(MapChainPassages, passage.id, age_days)
    passage
  end

  defp backdate(resource, id, age_days) do
    stamp = DateTime.utc_now() |> DateTime.add(-age_days * @seconds_per_day, :second)

    {1, _} =
      from(r in resource, where: r.id == ^id)
      |> Repo.update_all(set: [inserted_at: stamp, updated_at: stamp])

    :ok
  end

  defp remaining_passage_ids do
    {:ok, passages} = MapChainPassages.read()
    Enum.map(passages, & &1.id)
  end
end
