defmodule WandererApp.AccessListRepo do
  use WandererApp, :repository

  def get(acl_id, relationships \\ []) do
    acl_id
    |> WandererApp.Api.AccessList.by_id()
    |> case do
      {:ok, acl} ->
        acl |> load_relationships(relationships)

      _ ->
        {:error, :not_found}
    end
  end

  def load_relationships(acl, []), do: {:ok, acl}

  def load_relationships(acl, relationships), do: acl |> Ash.load(relationships)
end
