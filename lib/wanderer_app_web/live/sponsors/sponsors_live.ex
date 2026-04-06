defmodule WandererAppWeb.SponsorsLive do
  use WandererAppWeb, :live_view

  alias BetterNumber, as: Number

  require Logger

  @cache_key "server_top_donators"
  @cache_ttl :timer.minutes(15)

  @impl true
  def mount(_params, _session, socket) do
    if not WandererApp.Env.map_subscriptions_enabled?() do
      {:ok, socket |> redirect(to: "/")}
    else
      top_donators = load_top_donators()
      {corporation_id, corporation_info} = load_corporation_info()

      {:ok,
       assign(socket,
         page_title: "Sponsors",
         top_donators: top_donators,
         corporation_id: corporation_id,
         corporation_info: corporation_info
       )}
    end
  end

  def format_isk(amount) do
    Number.to_human(amount, units: ["", "K", "M", "B", "T", "P"])
  end

  defp load_top_donators do
    case Cachex.get(:api_cache, @cache_key) do
      {:ok, nil} ->
        donators = fetch_and_enrich()
        Cachex.put(:api_cache, @cache_key, donators, ttl: @cache_ttl)
        donators

      {:ok, cached} ->
        cached

      _ ->
        fetch_and_enrich()
    end
  end

  defp fetch_and_enrich do
    after_date = DateTime.utc_now() |> DateTime.add(-30, :day)

    case WandererApp.Api.MapTransaction.server_top_donators(%{after: after_date}) do
      {:ok, donators} ->
        enrich_with_characters(donators)

      {:error, reason} ->
        Logger.warning("Failed to load server top donators: #{inspect(reason)}")
        []
    end
  end

  defp enrich_with_characters(donators) do
    donators
    |> Enum.map(fn %{user_id: user_id, total_amount: total_amount} ->
      case WandererApp.Api.Character.active_by_user(%{user_id: user_id}) do
        {:ok, [character | _]} ->
          %{
            character_name: character.name,
            eve_id: character.eve_id,
            corporation_name: character.corporation_name,
            corporation_ticker: character.corporation_ticker,
            total_amount: total_amount
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp load_corporation_info do
    corp_eve_id = WandererApp.Env.corp_eve_id()

    if corp_eve_id == -1 do
      {nil, nil}
    else
      case WandererApp.Esi.get_corporation_info(corp_eve_id) do
        {:ok, info} -> {corp_eve_id, info}
        _ -> {nil, nil}
      end
    end
  end
end
