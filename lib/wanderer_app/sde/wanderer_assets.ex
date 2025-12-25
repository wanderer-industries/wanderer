defmodule WandererApp.SDE.WandererAssets do
  @moduledoc """
  Wanderer-Assets SDE data source implementation.

  This is the primary source for EVE Online Static Data Export files,
  directly parsed from CCP's official SDE by the wanderer-industries project.

  Source: https://github.com/wanderer-industries/wanderer-assets/tree/main/sde-files

  ## Available Files

  - `mapSolarSystems.csv` - Solar system data
  - `mapConstellations.csv` - Constellation mappings
  - `mapRegions.csv` - Region mappings
  - `mapLocationWormholeClasses.csv` - Wormhole class by location
  - `mapSolarSystemJumps.csv` - Gate connections
  - `invTypes.csv` - Ship/item types
  - `invGroups.csv` - Inventory groups
  - `npcStations.csv` - NPC station data (new)
  - `sde_metadata.json` - Version and generation metadata

  ## Version Tracking

  This source supports version tracking via `sde_metadata.json` which contains:

      {
        "sde_version": "3142455",
        "release_date": "2025-12-15T11:14:02Z",
        "generated_by": "wanderer-sde",
        "generated_at": "2025-12-18T21:03:27Z",
        "source": "https://developers.eveonline.com/static-data"
      }
  """

  @behaviour WandererApp.SDE.Source

  @default_base_url "https://raw.githubusercontent.com/wanderer-industries/wanderer-assets/main/sde-files"

  @impl true
  def base_url do
    Application.get_env(:wanderer_app, :sde)[:base_url] || @default_base_url
  end

  @impl true
  def file_url(filename) do
    # Validate filename doesn't contain path separators to prevent URL injection
    if String.contains?(filename, ["/", "\\"]) do
      raise ArgumentError, "filename must not contain path separators: #{inspect(filename)}"
    end

    "#{base_url()}/#{filename}"
  end

  @impl true
  def metadata_url do
    file_url("sde_metadata.json")
  end

  @doc """
  Returns the URL for the SDE version file.

  The version file contains just the SDE version number for quick checking.
  """
  @spec version_url() :: String.t()
  def version_url do
    file_url(".last-sde-version")
  end
end
