defmodule WandererApp.MapTransactionRepo do
  use WandererApp, :repository

  def create(transaction),
    do: WandererApp.Api.MapTransaction.create(transaction)

  def top_donators(map_id, after_date \\ nil),
    do: WandererApp.Api.MapTransaction.top_donators(%{map_id: map_id, after: after_date})
end
