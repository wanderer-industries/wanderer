defmodule WandererApp.MapRepo do
  use WandererApp, :repository

  def get(map_id, relationships \\ []) do
    map_id
    |> WandererApp.Api.Map.by_id()
    |> case do
      {:ok, map} ->
        map |> load_relationships(relationships)

      _ ->
        {:error, :not_found}
    end
  end

  def load_relationships(map, []), do: {:ok, map}

  def load_relationships(map, relationships), do: map |> Ash.load(relationships)

  def update_hubs(map_id, hubs) do
    map_id
    |> WandererApp.Api.Map.by_id()
    |> case do
      {:ok, map} ->
        map |> WandererApp.Api.Map.update_hubs(%{hubs: hubs})

      _ ->
        {:error, :map_not_found}
    end
  end
end
