defmodule WandererApp.MapTransactionRepo do
  use WandererApp, :repository

  def create(transaction),
    do: WandererApp.Api.MapTransaction.create(transaction)
end
