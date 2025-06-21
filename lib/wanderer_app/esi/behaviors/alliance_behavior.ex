defmodule WandererApp.Esi.AllianceBehavior do
  @moduledoc """
  Behavior for EVE ESI alliance API operations.
  """

  @callback get_alliance_info(alliance_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
