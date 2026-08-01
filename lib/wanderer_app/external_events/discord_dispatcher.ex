defmodule WandererApp.ExternalEvents.DiscordDispatcher do
  @moduledoc """
  Delivers `:map_kill` events to a map's configured Discord webhook.

  Filled in by a later task; for now only the cache-invalidation hook exists so
  the Ash resource can reference it.
  """

  @cache :discord_notification_cache

  @doc "Drops the cached config for a map after its record changes."
  def invalidate_cache(map_id) do
    Cachex.del(@cache, map_id)
    :ok
  rescue
    # The cache is not started in every context (e.g. unit tests); a missing
    # cache must not fail the write that triggered the invalidation.
    _ -> :ok
  end
end
