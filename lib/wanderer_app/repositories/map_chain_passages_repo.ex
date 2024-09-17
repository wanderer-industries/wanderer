defmodule WandererApp.MapChainPassagesRepo do
  use WandererApp, :repository

  def by_connection(map_id, from, to) do
    map_id
    |> WandererApp.Map.find_connection(
      from,
      to
    )
    |> case do
      {:ok, connection} ->
        {:ok, from_passages} =
          WandererApp.Api.MapChainPassages.by_connection(%{
            map_id: map_id,
            from: from,
            to: to,
            after: connection.inserted_at
          })

        {:ok, to_passages} =
          WandererApp.Api.MapChainPassages.by_connection(%{
            map_id: map_id,
            from: to,
            to: from,
            after: connection.inserted_at
          })

        from_passages =
          from_passages
          |> Enum.map(fn passage -> passage |> Map.put_new(:from, true) end)

        to_passages =
          to_passages
          |> Enum.map(fn passage -> passage |> Map.put_new(:from, false) end)

        passages =
          [from_passages | to_passages]
          |> List.flatten()

        {:ok, passages}

      {:error, _error} ->
        {:ok, []}
    end
  end
end
