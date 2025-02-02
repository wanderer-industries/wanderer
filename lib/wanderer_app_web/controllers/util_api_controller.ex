defmodule WandererAppWeb.UtilAPIController do
  @moduledoc """
  Utility functions for parameter handling, fetch helpers, etc.
  """

  alias WandererApp.Api

  def fetch_map_id(%{"map_id" => mid}) when is_binary(mid) and mid != "" do
    {:ok, mid}
  end

  def fetch_map_id(%{"slug" => slug}) when is_binary(slug) and slug != "" do
    case Api.Map.get_map_by_slug(slug) do
      {:ok, map} ->
        {:ok, map.id}

      {:error, _reason} ->
        {:error, "No map found for slug=#{slug}"}
    end
  end

  def fetch_map_id(_),
    do: {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"}

  # Require a given param to be present and non-empty
  def require_param(params, key) do
    case params[key] do
      nil -> {:error, "Missing required param: #{key}"}
      ""  -> {:error, "Param #{key} cannot be empty"}
      val -> {:ok, val}
    end
  end

  # Parse a string into an integer
  def parse_int(str) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _         -> {:error, "Invalid integer for param id=#{str}"}
    end
  end
end
