defmodule WandererApp.MapSubscriptionRepo do
  use WandererApp, :repository

  def cancel(sub), do: sub |> WandererApp.Api.MapSubscription.cancel()

  def expire(sub), do: sub |> WandererApp.Api.MapSubscription.expire()

  def get_all_active(),
    do: WandererApp.Api.MapSubscription.all_active()

  def get_all_by_map(map_id),
    do: WandererApp.Api.MapSubscription.all_by_map(%{map_id: map_id})

  def get_active_by_map(map_id),
    do: WandererApp.Api.MapSubscription.active_by_map(%{map_id: map_id})

  def load_relationships(sub, []), do: {:ok, sub}

  def load_relationships(sub, relationships), do: sub |> Ash.load(relationships)

  def update_active_till(sub, active_till),
    do:
      sub
      |> WandererApp.Api.MapSubscription.update_active_till(%{active_till: active_till})
end
