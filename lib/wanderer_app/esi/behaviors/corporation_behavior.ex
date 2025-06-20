defmodule WandererApp.Esi.CorporationBehavior do
  @moduledoc """
  Behavior for EVE ESI corporation API operations.
  """

  @callback get_corporation_info(corporation_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback get_corporation_wallets(corporation_id :: String.t(), opts :: keyword()) ::
              {:ok, list(map())} | {:error, term()}

  @callback get_corporation_wallet_journal(
              corporation_id :: String.t(),
              division :: integer(),
              opts :: keyword()
            ) ::
              {:ok, list(map())} | {:error, term()}

  @callback get_corporation_wallet_transactions(
              corporation_id :: String.t(),
              division :: integer(),
              opts :: keyword()
            ) ::
              {:ok, list(map())} | {:error, term()}
end
