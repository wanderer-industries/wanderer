defmodule WandererApp.SdeVersionRepo do
  @moduledoc """
  Repository for SDE version tracking operations.

  Provides functions for recording and querying SDE version history.
  """

  use WandererApp, :repository

  require Logger

  alias WandererApp.Api.SdeVersion

  @doc """
  Records an SDE update in the database.

  ## Options
  - `:metadata` - Optional metadata map from the SDE source

  ## Examples

      record_update("3142455", :wanderer_assets, ~U[2025-12-15 11:14:02Z])
      record_update("3142455", :wanderer_assets, nil, metadata: %{"generated_by" => "wanderer-sde"})
  """
  @spec record_update(String.t() | nil, atom(), DateTime.t() | nil, keyword()) ::
          {:ok, SdeVersion.t()} | {:error, term()}
  def record_update(version, source, release_date, opts \\ []) do
    metadata = Keyword.get(opts, :metadata)

    attrs = %{
      sde_version: version || "unknown",
      source: source,
      release_date: release_date,
      metadata: metadata
    }

    SdeVersion.record_update(attrs)
  end

  @doc """
  Returns the most recent SDE version record.
  """
  @spec get_latest() :: {:ok, SdeVersion.t() | nil} | {:error, term()}
  def get_latest do
    case SdeVersion.get_latest() do
      {:ok, record} -> {:ok, record}
      {:error, %Ash.Error.Query.NotFound{}} -> {:ok, nil}
      error -> error
    end
  rescue
    e in [DBConnection.ConnectionError, Postgrex.Error, Ecto.Query.CastError] ->
      Logger.debug("SDE version table may not exist yet: #{Exception.message(e)}")
      {:ok, nil}

    _e in [Ash.Error.Query.NotFound] ->
      # Expected when no records exist
      {:ok, nil}

    e ->
      Logger.warning("Unexpected error fetching SDE version: #{inspect(e)}")

      # Re-raise in dev/test to surface bugs
      if Application.get_env(:wanderer_app, :env) in [:dev, :test] do
        reraise e, __STACKTRACE__
      else
        {:ok, nil}
      end
  end

  @doc """
  Returns the SDE update history, most recent first.

  ## Options
  - `:limit` - Maximum number of records to return (default: 10)
  """
  @spec get_history(keyword()) :: {:ok, list(SdeVersion.t())} | {:error, term()}
  def get_history(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    SdeVersion
    |> Ash.Query.sort(applied_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read()
  rescue
    e in [DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.debug("SDE version table may not exist yet: #{Exception.message(e)}")
      {:ok, []}
  end
end
