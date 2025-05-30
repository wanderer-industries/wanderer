defmodule WandererApp.Zkb.Provider.Parser.Enricher do
  @moduledoc """
  Handles enrichment of killmail data with additional information.
  Manages fetching and adding character, corporation, alliance, and ship information.
  """

  require Logger
  alias WandererApp.Esi.ApiClient
  alias WandererApp.CachedInfo
  alias WandererApp.Utils.HttpUtil

  @type killmail :: map()
  @type enrich_result :: {:ok, killmail()} | {:error, term()}

  @doc """
  Enriches a killmail with additional information.
  Returns:
    - `{:ok, enriched_km}` if enrichment was successful
    - `{:error, reason}` if enrichment failed
  """
  @spec enrich_killmail(killmail() | nil) :: enrich_result()
  def enrich_killmail(nil), do: {:error, :invalid_killmail}
  def enrich_killmail({:error, reason}), do: {:error, reason}
  def enrich_killmail(km) when is_map(km) do
    try do
      with {:ok, victim_km} <- enrich_victim(km),
           {:ok, final_km} <- enrich_final_blow(victim_km) do
        {:ok, final_km}
      else
        {:error, reason} ->
          Logger.error("[Enricher] Failed to enrich killmail #{inspect(km["killmail_id"])}: #{inspect(reason)}")
          {:error, {:enrichment_failed, reason}}
      end
    rescue
      e ->
        Logger.error("[Enricher] Failed to enrich killmail #{inspect(km["killmail_id"])}: #{inspect(e)}")
        {:error, {:enrichment_failed, e}}
    end
  end
  def enrich_killmail(invalid) do
    Logger.error("[Enricher] Invalid killmail data: #{inspect(invalid)}")
    {:error, :invalid_killmail}
  end

  @spec enrich_victim(killmail()) :: {:ok, killmail()} | {:error, term()}
  defp enrich_victim(km) do
    try do

      # First enrich the victim data
      victim = km["victim"] || %{}

      enriched_victim = victim
        |> maybe_put_character_name("character_id", "character_name")
        |> maybe_put_corp_info("corporation_id", "corporation_ticker", "corporation_name")
        |> maybe_put_alliance_info("alliance_id", "alliance_ticker", "alliance_name")
        |> maybe_put_ship_name("ship_type_id", "ship_name")

      # Then enrich the root level victim fields
      enriched = km
        |> Map.put("victim", enriched_victim)
        |> maybe_put_character_name("victim_char_id", "victim_char_name")
        |> maybe_put_corp_info("victim_corp_id", "victim_corp_ticker", "victim_corp_name")
        |> maybe_put_alliance_info("victim_alliance_id", "victim_alliance_ticker", "victim_alliance_name")
        |> maybe_put_ship_name("victim_ship_type_id", "victim_ship_name")

      {:ok, enriched}
    rescue
      e ->
        Logger.error("[Enricher] Failed to enrich victim data for killmail #{inspect(km["killmail_id"])}: #{inspect(e)}")
        {:error, :victim_enrichment_failed}
    end
  end

  @spec enrich_final_blow(killmail()) :: {:ok, killmail()} | {:error, term()}
  defp enrich_final_blow(km) do
    try do
      # First enrich the final_blow data
      final_blow = km["final_blow"] || %{}

      enriched_final_blow = final_blow
        |> maybe_put_character_name("character_id", "character_name")
        |> maybe_put_corp_info("corporation_id", "corporation_ticker", "corporation_name")
        |> maybe_put_alliance_info("alliance_id", "alliance_ticker", "alliance_name")
        |> maybe_put_ship_name("ship_type_id", "ship_name")

      # Then enrich the root level final blow fields
      enriched = km
        |> Map.put("final_blow", enriched_final_blow)
        |> maybe_put_character_name("final_blow_char_id", "final_blow_char_name")
        |> maybe_put_corp_info("final_blow_corp_id", "final_blow_corp_ticker", "final_blow_corp_name")
        |> maybe_put_alliance_info("final_blow_alliance_id", "final_blow_alliance_ticker", "final_blow_alliance_name")
        |> maybe_put_ship_name("final_blow_ship_type_id", "final_blow_ship_name")

      {:ok, enriched}
    rescue
      e ->
        Logger.error("[Enricher] Failed to enrich final blow data for killmail #{inspect(km["killmail_id"])}: #{inspect(e)}")
        {:error, :final_blow_enrichment_failed}
    end
  end

  @spec maybe_put_character_name(killmail(), String.t(), String.t()) :: killmail()
  defp maybe_put_character_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      id when id in [nil, 0] ->
        km
      id when is_binary(id) ->
        case Integer.parse(id) do
          {eve_id, ""} ->
            handle_character_info(km, eve_id, name_key)
          _ ->
            km
        end
      eve_id when is_integer(eve_id) ->
        handle_character_info(km, eve_id, name_key)
      _ ->
        km
    end
  end

  @spec handle_character_info(killmail(), integer(), String.t()) :: killmail()
  defp handle_character_info(km, eve_id, name_key) do
    case fetch_character_info(eve_id) do
      {:ok, char_name} ->
        Map.put(km, name_key, char_name)
      :skip ->
        km
      {:error, reason} ->
        Logger.warning("[Enricher] Error fetching character info for ID #{eve_id}: #{inspect(reason)}")
        km
    end
  end

  @spec fetch_character_info(integer()) :: {:ok, String.t()} | :skip | {:error, term()}
  defp fetch_character_info(eve_id) when is_integer(eve_id) do
    try do
      HttpUtil.retry_with_backoff(
        fn ->
          case ApiClient.get_character_info(eve_id) do
            {:ok, %{"name" => char_name}} -> {:ok, char_name}
            {:error, :timeout} ->
              Logger.warning("[Enricher] Timeout fetching character info for ID #{eve_id}")
              raise "Character info timeout, will retry"
            {:error, :not_found} ->
              Logger.warning("[Enricher] Character not found for ID #{eve_id}")
              :skip
            {:error, reason} ->
              Logger.error("[Enricher] Error fetching character info for ID #{eve_id}: #{inspect(reason)}")
              if HttpUtil.retriable_error?(reason) do
                raise "Character info error: #{inspect(reason)}, will retry"
              else
                :skip
              end
          end
        end,
        max_retries: 3
      )
    rescue
      e ->
        Logger.warning("[Enricher] All retries exhausted for character info #{eve_id}: #{inspect(e)}")
        :skip
    catch
      :exit, reason ->
        Logger.warning("[Enricher] Exit during character info fetch for #{eve_id}: #{inspect(reason)}")
        :skip
      kind, reason ->
        Logger.warning("[Enricher] Unexpected error during character info fetch for #{eve_id}: #{inspect({kind, reason})}")
        :skip
    end
  end
  defp fetch_character_info(_), do: :skip

  @spec maybe_put_corp_info(killmail(), String.t(), String.t(), String.t()) :: killmail()
  defp maybe_put_corp_info(km, id_key, ticker_key, name_key) do
    case Map.get(km, id_key) do
      id when id in [nil, 0] -> km
      id when is_binary(id) ->
        case Integer.parse(id) do
          {corp_id, ""} ->
            handle_corp_info(km, corp_id, ticker_key, name_key)
          _ ->
            km
        end
      corp_id when is_integer(corp_id) ->
        handle_corp_info(km, corp_id, ticker_key, name_key)
      _ ->
        km
    end
  end

  @spec handle_corp_info(killmail(), integer(), String.t(), String.t()) :: killmail()
  defp handle_corp_info(km, corp_id, ticker_key, name_key) do
    fetch_corp_info(corp_id)
    |> handle_corp_result(km, corp_id, ticker_key, name_key)
  end

  @spec fetch_corp_info(integer()) :: {:ok, {String.t(), String.t()}} | :skip | {:error, term()}
  defp fetch_corp_info(corp_id) do
    HttpUtil.retry_with_backoff(
      fn ->
        case ApiClient.get_corporation_info(corp_id) do
          {:ok, %{"ticker" => ticker, "name" => corp_name}} -> {:ok, {ticker, corp_name}}
          {:error, :timeout} ->
            Logger.warning("[Enricher] Timeout fetching corporation info for ID #{corp_id}")
            raise "Corporation info timeout, will retry"
          {:error, :not_found} ->
            Logger.warning("[Enricher] Corporation not found for ID #{corp_id}")
            :skip
          {:error, reason} ->
            Logger.error("[Enricher] Error fetching corporation info for ID #{corp_id}: #{inspect(reason)}")
            handle_corp_error(reason, corp_id)
        end
      end,
      max_retries: 3
    )
  end

  @spec handle_corp_error(term(), integer()) :: :skip | no_return()
  defp handle_corp_error(reason, _corp_id) do
    if HttpUtil.retriable_error?(reason) do
      raise "Corporation info error: #{inspect(reason)}, will retry"
    else
      :skip
    end
  end

  @spec handle_corp_result({:ok, {String.t(), String.t()}} | :skip | {:error, term()}, killmail(), integer(), String.t(), String.t()) :: killmail()
  defp handle_corp_result({:ok, {ticker, corp_name}}, km, _corp_id, ticker_key, name_key) do
    km
    |> Map.put(ticker_key, ticker)
    |> Map.put(name_key, corp_name)
  end
  defp handle_corp_result(:skip, km, _corp_id, _ticker_key, _name_key) do
    km
  end
  defp handle_corp_result({:error, reason}, km, corp_id, _ticker_key, _name_key) do
    Logger.warning("[Enricher] Error handling corp info for ID #{corp_id}: #{inspect(reason)}")
    km
  end

  @spec maybe_put_alliance_info(killmail(), String.t(), String.t(), String.t()) :: killmail()
  defp maybe_put_alliance_info(km, id_key, ticker_key, name_key) do
    case Map.get(km, id_key) do
      id when id in [nil, 0] -> km
      id when is_binary(id) ->
        case Integer.parse(id) do
          {alliance_id, ""} ->
            handle_alliance_info(km, alliance_id, ticker_key, name_key)
          _ ->
            Logger.debug("[Enricher] Invalid alliance ID format: #{inspect(id)}")
            km
        end
      alliance_id when is_integer(alliance_id) ->
        handle_alliance_info(km, alliance_id, ticker_key, name_key)
      _ ->
        Logger.debug("[Enricher] Skipping alliance info for invalid ID type: #{inspect(Map.get(km, id_key))}")
        km
    end
  end

  @spec handle_alliance_info(killmail(), integer(), String.t(), String.t()) :: killmail()
  defp handle_alliance_info(km, alliance_id, ticker_key, name_key) do
    fetch_alliance_info(alliance_id)
    |> handle_alliance_result(km, alliance_id, ticker_key, name_key)
  end

  @spec fetch_alliance_info(integer()) :: {:ok, {String.t(), String.t()}} | :skip | {:error, term()}
  defp fetch_alliance_info(alliance_id) do
    HttpUtil.retry_with_backoff(
      fn ->
        case ApiClient.get_alliance_info(alliance_id) do
          {:ok, %{"ticker" => alliance_ticker, "name" => alliance_name}} -> {:ok, {alliance_ticker, alliance_name}}
          {:error, :timeout} ->
            Logger.warning("[Enricher] Timeout fetching alliance info for ID #{alliance_id}")
            raise "Alliance info timeout, will retry"
          {:error, :not_found} ->
            Logger.warning("[Enricher] Alliance not found for ID #{alliance_id}")
            :skip
          {:error, reason} ->
            Logger.error("[Enricher] Error fetching alliance info for ID #{alliance_id}: #{inspect(reason)}")
            handle_alliance_error(reason)
        end
      end,
      max_retries: 3
    )
  end

  @spec handle_alliance_error(term()) :: :skip | no_return()
  defp handle_alliance_error(reason) do
    if HttpUtil.retriable_error?(reason) do
      raise "Alliance info error: #{inspect(reason)}, will retry"
    else
      :skip
    end
  end

  @spec handle_alliance_result({:ok, {String.t(), String.t()}} | :skip | {:error, term()}, killmail(), integer(), String.t(), String.t()) :: killmail()
  defp handle_alliance_result({:ok, {alliance_ticker, alliance_name}}, km, _alliance_id, ticker_key, name_key) do
    km
    |> Map.put(ticker_key, alliance_ticker)
    |> Map.put(name_key, alliance_name)
  end
  defp handle_alliance_result(:skip, km, _alliance_id, _ticker_key, _name_key) do
    km
  end
  defp handle_alliance_result({:error, reason}, km, alliance_id, _ticker_key, _name_key) do
    Logger.warning("[Enricher] Error handling alliance info for ID #{alliance_id}: #{inspect(reason)}")
    km
  end

  @spec maybe_put_ship_name(killmail(), String.t(), String.t()) :: killmail()
  defp maybe_put_ship_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      id when id in [nil, 0] -> km
      type_id ->
        handle_ship_info(km, type_id, name_key)
    end
  end

  @spec handle_ship_info(killmail(), integer(), String.t()) :: killmail()
  defp handle_ship_info(km, type_id, name_key) do
    case CachedInfo.get_ship_type(type_id) do
      {:ok, %{name: ship_name}} -> Map.put(km, name_key, ship_name)
      {:ok, nil} ->
        Logger.warning("[Enricher] Ship type not found for ID #{type_id}")
        km
      {:error, :not_found} ->
        Logger.warning("[Enricher] Ship type not found for ID #{type_id}")
        km
      {:error, reason} ->
        Logger.error("[Enricher] Error fetching ship info for type ID #{type_id}: #{inspect(reason)}")
        km
    end
  end
end
