defmodule WandererApp.Zkb.KillsProvider do
  @moduledoc """
  Facade for handling zKillboard kills, both via:
  - Multi-page API fetch and caching (`fetch_kills_for_system/3`)
  - Local cache retrieval only (`fetch_kills_for_system_from_cache/1`)

  Also delegates to the websocket flow for real-time streaming:
  - `handle_connect/3`
  - `handle_in/2`
  - `handle_control/2`
  - `handle_info/2`
  - `handle_disconnect/3`
  - `handle_error/2`
  - `handle_terminate/2`
  """

  use Fresh
  require Logger

  # Pull in the submodules for convenience
  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererApp.Zkb.KillsProvider.{Websocket, Fetcher}

  defstruct [:connected]

  @doc """
  Fetch kills for the given `system_id` in the last `since_hours` hours,
  potentially doing multi-page calls to zKillboard's API,
  then returning the kills from the cache along with updated state.

  - `system_id`: integer ID of EVE solar system
  - `since_hours`: integer hours to go back
  - `preloader_state`: a struct containing relevant preload info (like `calls_count`).
  """
  def fetch_kills_for_system(system_id, since_hours, preloader_state) do
    Fetcher.fetch_kills_for_system(system_id, since_hours, preloader_state)
  end

  @doc """
  Fetch kills for multiple systems in one call.
  """
  def fetch_kills_for_systems(system_ids, since_hours, preloader_state) do
    Fetcher.fetch_kills_for_systems(system_ids, since_hours, preloader_state)
  end


  @doc """
  Retrieve kills for the given `system_id` **strictly from the cache**
  (i.e., without triggering any fetch from zKillboard).
  """
  def fetch_kills_for_system_from_cache(system_id) do
    KillsCache.fetch_cached_kills(system_id)
  end

  # ------------------------------------------------------------------
  # Websocket Flow – delegated to WandererApp.Zkb.KillsProvider.Websocket
  # ------------------------------------------------------------------
  def handle_connect(status, headers, state),
    do: Websocket.handle_connect(status, headers, state)

  def handle_in(frame, state),
    do: Websocket.handle_in(frame, state)

  def handle_control(msg, state),
    do: Websocket.handle_control(msg, state)

  def handle_info(msg, state),
    do: Websocket.handle_info(msg, state)

  def handle_disconnect(code, reason, state),
    do: Websocket.handle_disconnect(code, reason, state)

  def handle_error(err, state),
    do: Websocket.handle_error(err, state)

  def handle_terminate(reason, state),
    do: Websocket.handle_terminate(reason, state)
end
