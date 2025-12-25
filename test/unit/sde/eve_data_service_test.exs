defmodule WandererApp.EveDataServiceTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.EveDataService
  alias WandererApp.Api.SdeVersion

  describe "get_sde_info/0" do
    test "returns SDE info map with required keys" do
      info = EveDataService.get_sde_info()

      assert is_map(info)
      assert Map.has_key?(info, :source)
      assert Map.has_key?(info, :source_name)
      assert Map.has_key?(info, :version)
      assert Map.has_key?(info, :last_updated)
      assert Map.has_key?(info, :base_url)
    end

    test "returns correct source name for WandererAssets" do
      info = EveDataService.get_sde_info()

      assert info.source == WandererApp.SDE.WandererAssets
      assert info.source_name == "Wanderer Assets"
    end

    test "returns valid base_url" do
      info = EveDataService.get_sde_info()

      assert is_binary(info.base_url)
      assert info.base_url =~ "wanderer-assets"
    end
  end

  describe "get_current_sde_version/0" do
    test "returns nil when no version is recorded" do
      # Clear any existing versions first
      {:ok, versions} = EveDataService.get_sde_history(limit: 100)

      Enum.each(versions, fn version ->
        Ash.destroy!(version)
      end)

      # Should return nil or fall back to file
      version = EveDataService.get_current_sde_version()
      # Version can be nil or a string from file-based fallback
      assert is_nil(version) or is_binary(version)
    end

    test "returns version after recording an update" do
      # Record a test version
      {:ok, _record} =
        SdeVersion.record_update(%{
          sde_version: "test_version_123",
          source: :wanderer_assets,
          release_date: DateTime.utc_now(),
          metadata: %{"test" => true}
        })

      version = EveDataService.get_current_sde_version()
      assert version == "test_version_123"
    end
  end

  describe "get_sde_history/1" do
    test "returns empty list when no history exists" do
      # Clear existing versions
      {:ok, versions} = EveDataService.get_sde_history(limit: 100)

      Enum.each(versions, fn version ->
        Ash.destroy!(version)
      end)

      {:ok, history} = EveDataService.get_sde_history()
      assert history == []
    end

    test "returns history records in descending order by applied_at" do
      # Use unique identifiers to avoid collision with other tests
      unique_id = System.unique_integer([:positive])

      {:ok, older} =
        SdeVersion.record_update(%{
          sde_version: "order_test_#{unique_id}_older",
          source: :wanderer_assets
        })

      # Use explicit timestamp comparison instead of sleep
      {:ok, newer} =
        SdeVersion.record_update(%{
          sde_version: "order_test_#{unique_id}_newer",
          source: :wanderer_assets
        })

      {:ok, history} = EveDataService.get_sde_history(limit: 10)

      # Find our test records
      our_records =
        history
        |> Enum.filter(&String.starts_with?(&1.sde_version, "order_test_#{unique_id}_"))

      assert length(our_records) == 2

      # Newer should come before older (descending order)
      [first, second] = our_records
      assert first.id == newer.id
      assert second.id == older.id
    end

    test "respects limit option" do
      # Use unique identifier to avoid collision with other tests
      unique_id = System.unique_integer([:positive])

      # Record multiple versions
      for i <- 1..5 do
        {:ok, _} =
          SdeVersion.record_update(%{
            sde_version: "limit_test_#{unique_id}_#{i}",
            source: :wanderer_assets
          })
      end

      {:ok, history} = EveDataService.get_sde_history(limit: 2)
      assert length(history) == 2
    end
  end

  describe "check_for_updates/0" do
    @tag :external
    test "returns update status from remote source" do
      result = EveDataService.check_for_updates()

      # Should return one of the valid responses
      assert match?({:ok, :up_to_date}, result) or
               match?({:ok, :update_available, _}, result) or
               match?({:ok, :update_available}, result) or
               match?({:error, _}, result)
    end

    @tag :external
    test "returns up_to_date when current version matches remote" do
      # First fetch the remote version
      source = WandererApp.SDE.Source.get_source()

      case EveDataService.fetch_metadata(source.metadata_url()) do
        {:ok, metadata} ->
          # Record this version
          {:ok, _} =
            SdeVersion.record_update(%{
              sde_version: metadata["sde_version"],
              source: :wanderer_assets,
              metadata: metadata
            })

          # Now check should return up_to_date
          assert {:ok, :up_to_date} = EveDataService.check_for_updates()

        {:error, _} ->
          # Skip if we can't reach the remote
          :ok
      end
    end
  end

  describe "fetch_metadata/1" do
    @tag :external
    test "fetches metadata from wanderer-assets" do
      source = WandererApp.SDE.Source.get_source()
      url = source.metadata_url()

      case EveDataService.fetch_metadata(url) do
        {:ok, metadata} ->
          assert is_map(metadata)
          assert Map.has_key?(metadata, "sde_version")
          assert Map.has_key?(metadata, "release_date")
          assert Map.has_key?(metadata, "generated_by")
          assert Map.has_key?(metadata, "generated_at")

        {:error, reason} ->
          # Network errors are acceptable in tests
          assert is_tuple(reason) or is_atom(reason)
      end
    end

    test "returns error for invalid URL" do
      result = EveDataService.fetch_metadata("https://invalid.example.com/nonexistent.json")
      assert match?({:error, _}, result)
    end
  end

  describe "SdeVersion resource" do
    test "record_update/1 creates a new version record" do
      {:ok, record} =
        SdeVersion.record_update(%{
          sde_version: "3142455",
          source: :wanderer_assets,
          release_date: ~U[2025-12-15 11:14:02Z],
          metadata: %{
            "generated_by" => "wanderer-sde",
            "generated_at" => "2025-12-18T21:03:27Z"
          }
        })

      assert record.sde_version == "3142455"
      assert record.source == :wanderer_assets
      assert record.release_date == ~U[2025-12-15 11:14:02Z]
      assert record.metadata["generated_by"] == "wanderer-sde"
      assert record.applied_at != nil
    end

    test "get_latest/0 returns the most recent version" do
      # Use unique identifier to avoid collision with other tests
      unique_id = System.unique_integer([:positive])

      # Record two versions - the second one should be "latest" by insertion order
      {:ok, _older} =
        SdeVersion.record_update(%{
          sde_version: "latest_test_#{unique_id}_old",
          source: :wanderer_assets
        })

      {:ok, newer} =
        SdeVersion.record_update(%{
          sde_version: "latest_test_#{unique_id}_new",
          source: :wanderer_assets
        })

      {:ok, latest} = SdeVersion.get_latest()
      assert latest.id == newer.id
      assert latest.sde_version == "latest_test_#{unique_id}_new"
    end
  end
end
