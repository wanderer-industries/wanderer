defmodule WandererApp.SDE.SourceTest do
  use ExUnit.Case, async: true

  alias WandererApp.SDE.Source
  alias WandererApp.SDE.WandererAssets
  alias WandererApp.SDE.Fuzzworks

  describe "get_source/0" do
    test "returns WandererAssets by default" do
      # Default configuration should return WandererAssets
      assert Source.get_source() == WandererAssets
    end
  end

  describe "WandererAssets" do
    test "base_url/0 returns correct URL" do
      url = WandererAssets.base_url()
      assert is_binary(url)
      assert url =~ "wanderer-industries/wanderer-assets"
      assert url =~ "sde-files"
    end

    test "file_url/1 generates correct URL for CSV files" do
      url = WandererAssets.file_url("mapSolarSystems.csv")
      assert url =~ "wanderer-industries/wanderer-assets"
      assert url =~ "sde-files/mapSolarSystems.csv"
    end

    test "file_url/1 works with different file names" do
      files = [
        "invGroups.csv",
        "invTypes.csv",
        "mapConstellations.csv",
        "mapRegions.csv",
        "mapLocationWormholeClasses.csv",
        "mapSolarSystemJumps.csv"
      ]

      for file <- files do
        url = WandererAssets.file_url(file)
        assert url =~ file
        assert url =~ "sde-files"
      end
    end

    test "metadata_url/0 returns sde_metadata.json URL" do
      url = WandererAssets.metadata_url()
      assert is_binary(url)
      assert url =~ "sde_metadata.json"
    end

    test "version_url/0 returns .last-sde-version URL" do
      url = WandererAssets.version_url()
      assert is_binary(url)
      assert url =~ ".last-sde-version"
    end
  end

  describe "Fuzzworks" do
    test "base_url/0 returns correct URL" do
      url = Fuzzworks.base_url()
      assert url == "https://www.fuzzwork.co.uk/dump/latest"
    end

    test "file_url/1 generates correct URL for CSV files" do
      url = Fuzzworks.file_url("mapSolarSystems.csv")
      assert url == "https://www.fuzzwork.co.uk/dump/latest/mapSolarSystems.csv"
    end

    test "metadata_url/0 returns nil (not supported)" do
      assert Fuzzworks.metadata_url() == nil
    end
  end
end
