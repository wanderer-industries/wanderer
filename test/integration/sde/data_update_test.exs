defmodule WandererApp.SDE.DataUpdateTest do
  @moduledoc """
  Integration tests for SDE data update functionality.

  These tests verify the full update flow including:
  - Downloading files from the configured source
  - Processing and storing data
  - Version tracking

  Note: Tests marked with @tag :external require network access
  and may be slow. They are excluded from regular test runs.
  """

  use WandererApp.DataCase, async: false

  alias WandererApp.EveDataService
  alias WandererApp.SDE.Source
  alias WandererApp.SDE.WandererAssets

  @moduletag :integration

  describe "SDE source configuration" do
    test "default source is WandererAssets" do
      source = Source.get_source()
      assert source == WandererAssets
    end

    test "source provides valid base URL" do
      source = Source.get_source()
      base_url = source.base_url()

      assert is_binary(base_url)
      assert String.starts_with?(base_url, "https://")
    end

    test "source generates valid file URLs for all required files" do
      source = Source.get_source()

      required_files = [
        "invGroups.csv",
        "invTypes.csv",
        "mapConstellations.csv",
        "mapRegions.csv",
        "mapLocationWormholeClasses.csv",
        "mapSolarSystems.csv",
        "mapSolarSystemJumps.csv"
      ]

      for file <- required_files do
        url = source.file_url(file)
        assert is_binary(url)
        assert String.ends_with?(url, file)
        assert String.starts_with?(url, "https://")
      end
    end
  end

  describe "metadata fetching" do
    @tag :external
    test "can fetch metadata from wanderer-assets" do
      source = Source.get_source()

      case source.metadata_url() do
        nil ->
          # Fuzzworks doesn't support metadata
          assert source == WandererApp.SDE.Fuzzworks

        url ->
          result = EveDataService.fetch_metadata(url)

          case result do
            {:ok, metadata} ->
              assert is_map(metadata)
              assert is_binary(metadata["sde_version"])
              assert is_binary(metadata["release_date"])

            {:error, _reason} ->
              # Network errors are acceptable in CI
              :ok
          end
      end
    end
  end

  describe "version tracking" do
    test "version is tracked after simulated update" do
      # Simulate what happens after update_eve_data completes
      test_version = "test_#{System.unique_integer([:positive])}"

      {:ok, record} =
        WandererApp.Api.SdeVersion.record_update(%{
          sde_version: test_version,
          source: :wanderer_assets,
          release_date: DateTime.utc_now(),
          metadata: %{"test" => true}
        })

      assert record.sde_version == test_version
      assert record.source == :wanderer_assets

      # Verify it's retrievable
      current_version = EveDataService.get_current_sde_version()
      assert current_version == test_version
    end

    test "multiple versions are tracked in history" do
      base_version = System.unique_integer([:positive])

      # Record multiple versions
      records =
        for i <- 1..3 do
          {:ok, record} =
            WandererApp.Api.SdeVersion.record_update(%{
              sde_version: "history_test_#{base_version}_#{i}",
              source: :wanderer_assets
            })

          record
        end

      {:ok, history} = EveDataService.get_sde_history(limit: 10)

      # Find our test records
      our_records =
        history
        |> Enum.filter(&String.starts_with?(&1.sde_version, "history_test_#{base_version}_"))

      # Should have our 3 test versions
      assert length(our_records) == 3

      # Latest should be first (history_test_N_3)
      [latest | _] = our_records
      assert latest.id == List.last(records).id
    end
  end

  describe "SDE info display" do
    test "get_sde_info returns complete information" do
      info = EveDataService.get_sde_info()

      # All required fields should be present
      assert Map.has_key?(info, :source)
      assert Map.has_key?(info, :source_name)
      assert Map.has_key?(info, :version)
      assert Map.has_key?(info, :last_updated)
      assert Map.has_key?(info, :base_url)

      # Source should be a module
      assert is_atom(info.source)
      assert info.source in [WandererAssets, WandererApp.SDE.Fuzzworks]

      # Source name should be readable
      assert info.source_name in ["Wanderer Assets", "Fuzzworks (Legacy)"]

      # Base URL should be valid
      assert is_binary(info.base_url)
      assert String.starts_with?(info.base_url, "https://")
    end
  end

  describe "update checking" do
    @tag :external
    test "check_for_updates returns valid response" do
      result = EveDataService.check_for_updates()

      # Should return one of the valid responses
      case result do
        {:ok, :up_to_date} ->
          # Current version matches remote
          :ok

        {:ok, :update_available, metadata} ->
          # New version available
          assert is_map(metadata)
          assert Map.has_key?(metadata, "sde_version")

        {:ok, :update_available} ->
          # Source doesn't support version tracking
          :ok

        {:error, _reason} ->
          # Network error - acceptable in tests
          :ok
      end
    end
  end

  # These tests are marked as external and should only run
  # when explicitly requested, as they make actual HTTP requests
  describe "full update flow (external)" do
    @describetag :external
    @describetag :slow

    @tag timeout: 300_000
    test "update_eve_data downloads and processes files" do
      # This is a comprehensive test that actually downloads files
      # Only run when explicitly testing the full flow

      # Skip when explicitly requested (e.g., in CI without network access)
      if System.get_env("SKIP_NETWORK_TESTS") do
        :ok
      else
        result = EveDataService.update_eve_data()

        case result do
          :ok ->
            # Verify data was loaded
            info = EveDataService.get_sde_info()
            assert info.version != nil

          {:error, {:http_error, _, _}} ->
            # Network error - acceptable
            :ok

          {:error, {:download_failed, _, _}} ->
            # Download failure - acceptable in tests
            :ok
        end
      end
    end
  end
end
