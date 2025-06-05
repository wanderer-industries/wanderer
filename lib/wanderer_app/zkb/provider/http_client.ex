defmodule WandererApp.Zkb.Provider.HttpClient do
  @moduledoc """
  HTTP client for zKillboard API requests.
  """

  require Logger
  alias WandererApp.Utils.HttpUtil

  @base_url "https://zkillboard.com/api"
  @user_agent "WandererApp/1.0"
  @rate_limit_bucket "zkb"
  @rate_limit 1
  @rate_scale_ms 10_000

  @doc """
  Fetches a killmail by its ID.
  """
  @spec get_killmail(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_killmail(killmail_id) when is_integer(killmail_id) do
    build_url("killID", killmail_id)
    |> fetch_json()
    |> wrap_single_result()
  end

  @doc """
  Fetches all killmails for a system.
  """
  @spec get_system_killmails(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_system_killmails(system_id) when is_integer(system_id) do
    build_url("systemID", system_id)
    |> fetch_json()
    |> wrap_single_result()
  end

  @spec fetch_json(String.t()) :: {:ok, map() | [map()]} | {:error, term()}
  defp fetch_json(url) do
    with {:ok, body} <- do_request(url),
         {:ok, decoded} <- decode_json(body) do
      {:ok, decoded}
    else
      {:error, _} = error ->
        Logger.error("[ZkbHttpClient] Error fetching #{url}: #{inspect(error)}")
        error
      {:ok, unexpected} ->
        Logger.warning("[ZkbHttpClient] Unexpected response for #{url}: #{inspect(unexpected, limit: 50)}")
        {:error, :invalid_response}
    end
  end

  @spec wrap_single_result({:ok, map() | [map()]} | {:error, term()}) :: {:ok, [map()]} | {:error, term()}
  defp wrap_single_result({:ok, result}) when is_map(result), do: {:ok, [result]}
  defp wrap_single_result({:ok, result}) when is_list(result), do: {:ok, result}
  defp wrap_single_result(error), do: error

  @spec do_request(String.t()) :: {:ok, String.t() | map() | [map()]} | {:error, term()}
  defp do_request(url) do
    HttpUtil.get_with_rate_limit(
      url,
      headers: default_headers(),
      bucket: @rate_limit_bucket,
      limit: @rate_limit,
      scale_ms: @rate_scale_ms
    )
  end

  @spec decode_json(String.t() | map() | [map()]) :: {:ok, map() | [map()]} | {:error, term()}
  defp decode_json(body) when is_binary(body), do: Jason.decode(body)
  defp decode_json(body) when is_map(body) or is_list(body), do: {:ok, body}
  defp decode_json(_), do: {:error, :invalid_response}

  @spec default_headers() :: [{String.t(), String.t()}]
  defp default_headers do
    [
      {"User-Agent", @user_agent},
      {"Accept", "application/json"}
    ]
  end

  @spec build_url(String.t(), integer()) :: String.t()
  defp build_url("systemID", id), do: "#{@base_url}/systemID/#{id}/"
  defp build_url(endpoint, id), do: "#{@base_url}/#{endpoint}/#{id}/"
end
