defmodule WandererApp.ExternalEvents.SseAccessControl do
  @moduledoc """
  Handles SSE access control checks including subscription validation.

  IMPORTANT: This module is optimized for high-frequency calls during event delivery.
  All checks use cached data to avoid database queries on every event.

  Note: Community Edition mode is automatically handled - when subscriptions are
  disabled globally, we skip the subscription check entirely.
  """

  @doc """
  Checks if SSE is allowed for a given map.

  Returns:
  - :ok if SSE is allowed
  - {:error, reason} if SSE is not allowed

  Checks in order:
  1. Global SSE enabled (config check - no DB)
  2. Map SSE enabled (cache check - no DB)
  3. Subscription active (cache check or skipped in CE mode - no DB)
  """
  def sse_allowed?(map_id) do
    with :ok <- check_sse_globally_enabled(),
         :ok <- check_map_sse_enabled_cached(map_id),
         :ok <- check_subscription_or_ce_cached(map_id) do
      :ok
    end
  end

  defp check_sse_globally_enabled do
    if WandererApp.Env.sse_enabled?() do
      :ok
    else
      {:error, :sse_globally_disabled}
    end
  end

  # Uses the map cache with fallback to DB query
  defp check_map_sse_enabled_cached(map_id) do
    case WandererApp.Map.sse_enabled_with_status(map_id) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :sse_disabled_for_map}
      {:error, :not_found} -> {:error, :map_not_found}
    end
  end

  # Checks subscription status using cached data.
  # In CE mode (subscriptions disabled globally), this is a fast config check.
  # In Enterprise mode, uses cached map state's subscription settings.
  defp check_subscription_or_ce_cached(map_id) do
    # Fast path: CE mode - subscriptions disabled globally
    if not WandererApp.Env.map_subscriptions_enabled?() do
      :ok
    else
      # Enterprise mode: check cached subscription status from map state
      check_subscription_from_cache(map_id)
    end
  end

  # Checks subscription status from the map cache.
  # Falls back to DB query only if cache miss.
  defp check_subscription_from_cache(map_id) do
    case WandererApp.Map.subscription_active_cached?(map_id) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:error, :subscription_required}

      {:error, :not_cached} ->
        # Cache miss - fall back to DB check
        # This should be rare as maps are initialized when accessed
        fallback_subscription_check(map_id)
    end
  end

  # Fallback to DB query - only used when cache miss
  defp fallback_subscription_check(map_id) do
    case WandererApp.Map.is_subscription_active?(map_id) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :subscription_required}
      {:error, _reason} = error -> error
    end
  end
end
