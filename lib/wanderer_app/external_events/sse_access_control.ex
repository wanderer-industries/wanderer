defmodule WandererApp.ExternalEvents.SseAccessControl do
  @moduledoc """
  Handles SSE access control checks including subscription validation.

  Note: Community Edition mode is automatically handled by the
  WandererApp.Map.is_subscription_active?/1 function, which returns
  {:ok, true} when subscriptions are disabled globally.
  """

  @doc """
  Checks if SSE is allowed for a given map.

  Returns:
  - :ok if SSE is allowed
  - {:error, reason} if SSE is not allowed

  Checks in order:
  1. Global SSE enabled (config)
  2. Map exists
  3. Map SSE enabled (per-map setting)
  4. Subscription active (CE mode handled internally)
  """
  def sse_allowed?(map_id) do
    with :ok <- check_sse_globally_enabled(),
         {:ok, map} <- fetch_map(map_id),
         :ok <- check_map_sse_enabled(map),
         :ok <- check_subscription_or_ce(map_id) do
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

  # Fetches the map by ID.
  # Returns {:ok, map} or {:error, :map_not_found}
  defp fetch_map(map_id) do
    case WandererApp.Api.Map.by_id(map_id) do
      {:ok, _map} = result -> result
      _ -> {:error, :map_not_found}
    end
  end

  defp check_map_sse_enabled(map) do
    if map.sse_enabled do
      :ok
    else
      {:error, :sse_disabled_for_map}
    end
  end

  # Checks if map has active subscription or if running Community Edition.
  #
  # Returns :ok if:
  # - Community Edition (handled internally by is_subscription_active?/1), OR
  # - Map has active subscription
  #
  # Returns {:error, :subscription_required} if subscription check fails.
  defp check_subscription_or_ce(map_id) do
    case WandererApp.Map.is_subscription_active?(map_id) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :subscription_required}
      {:error, _reason} = error -> error
    end
  end
end
