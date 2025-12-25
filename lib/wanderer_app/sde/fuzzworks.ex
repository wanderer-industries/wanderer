defmodule WandererApp.SDE.Fuzzworks do
  @moduledoc """
  Legacy Fuzzworks SDE data source implementation.

  This is the deprecated data source from fuzzwork.co.uk.
  It is maintained for backward compatibility and rollback purposes.

  Source: https://www.fuzzwork.co.uk/dump/latest

  ## Deprecation Notice

  This source is deprecated in favor of `WandererApp.SDE.WandererAssets`.
  The wanderer-assets source provides:
  - Version tracking via metadata
  - Direct parsing from CCP's official SDE
  - Guaranteed availability via GitHub CDN

  ## Configuration

  To use this source (not recommended), set:

      SDE_SOURCE=fuzzworks

  Or in config:

      config :wanderer_app, :sde,
        source: :fuzzworks

  ## Limitations

  - No version tracking (metadata_url returns nil)
  - Third-party dependency on fuzzwork.co.uk availability
  - May lag behind official CCP releases
  """

  require Logger

  @behaviour WandererApp.SDE.Source

  @base_url "https://www.fuzzwork.co.uk/dump/latest"

  @impl true
  def base_url do
    Logger.warning("Using deprecated Fuzzworks SDE source. Please migrate to WandererAssets.")
    @base_url
  end

  @impl true
  def file_url(filename) do
    "#{@base_url}/#{filename}"
  end

  @impl true
  def metadata_url do
    # Fuzzworks does not provide version metadata
    nil
  end
end
