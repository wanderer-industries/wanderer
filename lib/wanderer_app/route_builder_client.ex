defmodule WandererApp.RouteBuilderClient do
  @moduledoc """
  HTTP client for the local route builder service.
  """

  require Logger

  @timeout_opts [pool_timeout: 5_000, receive_timeout: :timer.seconds(30)]
  @loot_dir Path.join(["repo", "data", "route_by_systems"])

  def find_closest(%{
        origin: origin,
        flag: flag,
        connections: connections,
        avoid: avoid,
        count: count,
        type: type,
        security_type: security_type
      }) do
    url = "#{WandererApp.Env.route_builder_base_url()}/route/findClosest"

    destinations = destinations_for(type, security_type)

    payload = %{
      origin: origin,
      flag: flag,
      connections: connections || [],
      avoid: avoid || [],
      destinations: destinations,
      count: count || 1
    }

    case Req.post(url, Keyword.merge([json: payload], @timeout_opts)) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[RouteBuilderClient] Unexpected status: #{status}")
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        Logger.error("[RouteBuilderClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp destinations_for(type, security_type) do
    case load_loot_data(type) do
      {:ok, %{"system_ids_by_band" => by_band}} ->
        high = Map.get(by_band, "high", [])
        low = Map.get(by_band, "low", [])
        pick_by_band(high, low, security_type)

      {:error, reason} ->
        Logger.error("[RouteBuilderClient] Failed to load loot data: #{inspect(reason)}")
        []
    end
  end

  def stations_for(type) do
    case load_loot_data(type) do
      {:ok, %{"system_stations" => system_stations}} when is_map(system_stations) ->
        system_stations

      {:ok, _} ->
        %{}

      {:error, reason} ->
        Logger.error("[RouteBuilderClient] Failed to load loot stations: #{inspect(reason)}")
        %{}
    end
  end

  defp pick_by_band(high, _low, "high"), do: high
  defp pick_by_band(high, _low, :high), do: high
  defp pick_by_band(high, _low, "hight"), do: high
  defp pick_by_band(high, _low, :hight), do: high
  defp pick_by_band(_high, low, "low"), do: low
  defp pick_by_band(_high, low, :low), do: low
  defp pick_by_band(high, low, _), do: high ++ low

  defp load_loot_data("blueLoot"), do: load_loot_file("blueloot.json")
  defp load_loot_data(:blueLoot), do: load_loot_file("blueloot.json")
  defp load_loot_data("redLoot"), do: load_loot_file("redloot.json")
  defp load_loot_data(:redLoot), do: load_loot_file("redloot.json")
  defp load_loot_data(_), do: load_loot_file("blueloot.json")

  defp load_loot_file(filename) do
    key = {__MODULE__, :loot_data, filename}

    case :persistent_term.get(key, :missing) do
      :missing ->
        path = Path.join([:code.priv_dir(:wanderer_app), @loot_dir, filename])

        with {:ok, body} <- File.read(path),
             {:ok, json} <- Jason.decode(body) do
          :persistent_term.put(key, json)
          {:ok, json}
        else
          error -> error
        end

      cached ->
        {:ok, cached}
    end
  end
end
