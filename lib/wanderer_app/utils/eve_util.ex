defmodule WandererApp.Utils.EVEUtil do
  @moduledoc """
  Utility functions for EVE Online related operations.
  """

  alias WandererApp.Map.Operations.Connections

  @doc """
  Generates a URL for a character portrait.

  ## Parameters
    * `eve_id` - The EVE Online character ID
    * `size` - The size of the portrait (default: 64)

  ## Examples
      iex> WandererApp.Utils.EVEUtil.get_portrait_url(12345678)
      "https://images.evetech.net/characters/12345678/portrait?size=64"

      iex> WandererApp.Utils.EVEUtil.get_portrait_url(12345678, 128)
      "https://images.evetech.net/characters/12345678/portrait?size=128"
  """
  def get_portrait_url(eve_id, size \\ 64)

  def get_portrait_url(nil, size),
    do: "https://images.evetech.net/characters/0/portrait?size=#{size}"

  def get_portrait_url("", size),
    do: "https://images.evetech.net/characters/0/portrait?size=#{size}"

  def get_portrait_url(eve_id, size) do
    "https://images.evetech.net/characters/#{eve_id}/portrait?size=#{size}"
  end

  def get_wh_size(nil), do: nil
  def get_wh_size("K162"), do: nil

  def get_wh_size(wh_type_name) do
    {:ok, wormhole_types} = WandererApp.CachedInfo.get_wormhole_types()

    wormhole_types
    |> Enum.find(fn wh_type_data -> wh_type_data.name == wh_type_name end)
    |> case do
      %{max_mass_per_jump: max_mass_per_jump} when not is_nil(max_mass_per_jump) ->
        get_connection_size_status(max_mass_per_jump)

      _ ->
        nil
    end
  end

  defp get_connection_size_status(5_000_000), do: Connections.small_ship_size()
  defp get_connection_size_status(62_000_000), do: Connections.medium_ship_size()
  defp get_connection_size_status(375_000_000), do: Connections.large_ship_size()
  defp get_connection_size_status(1_000_000_000), do: Connections.freight_ship_size()
  defp get_connection_size_status(2_000_000_000), do: Connections.capital_ship_size()
  defp get_connection_size_status(_max_mass_per_jump), do: Connections.large_ship_size()
end
