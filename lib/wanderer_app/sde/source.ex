defmodule WandererApp.SDE.Source do
  @moduledoc """
  Behaviour for SDE (Static Data Export) data sources.

  This abstraction allows switching between different SDE providers:
  - `:wanderer_assets` - Primary source from wanderer-industries/wanderer-assets
  - `:fuzzworks` - Legacy source from fuzzwork.co.uk (deprecated)

  ## Configuration

  The active source is configured in `config/runtime.exs`:

      config :wanderer_app, :sde,
        source: :wanderer_assets,
        base_url: "https://raw.githubusercontent.com/wanderer-industries/wanderer-assets/main/sde-files"

  Or via environment variables:

      SDE_SOURCE=wanderer_assets
      SDE_BASE_URL=https://raw.githubusercontent.com/wanderer-industries/wanderer-assets/main/sde-files
  """

  @doc """
  Returns the base URL for the SDE data source.
  """
  @callback base_url() :: String.t()

  @doc """
  Returns the full URL for a specific file from the SDE source.
  """
  @callback file_url(filename :: String.t()) :: String.t()

  @doc """
  Returns the URL for the SDE metadata file, or nil if not supported.

  Metadata contains version information and timestamps for the SDE data.
  """
  @callback metadata_url() :: String.t() | nil

  @doc """
  Returns the configured SDE source module based on application configuration.

  Defaults to `WandererApp.SDE.WandererAssets` if not configured.
  """
  @spec get_source() :: module()
  def get_source do
    case Application.get_env(:wanderer_app, :sde)[:source] do
      :fuzzworks -> WandererApp.SDE.Fuzzworks
      _ -> WandererApp.SDE.WandererAssets
    end
  end
end
