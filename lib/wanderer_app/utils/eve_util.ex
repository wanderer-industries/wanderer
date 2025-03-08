defmodule WandererApp.Utils.EVEUtil do
  @moduledoc """
  Utility functions for EVE Online related operations.
  """

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
  def get_portrait_url(nil, size), do: "https://images.evetech.net/characters/0/portrait?size=#{size}"
  def get_portrait_url("", size), do: "https://images.evetech.net/characters/0/portrait?size=#{size}"
  def get_portrait_url(eve_id, size) do
    "https://images.evetech.net/characters/#{eve_id}/portrait?size=#{size}"
  end
end
