defmodule WandererApp.Zkb.KillsProvider.ZkbApi do
  @moduledoc """
  A small module for making HTTP requests to zKillboard and
  parsing JSON responses, separate from the multi-page logic.
  """

  require Logger
  alias ExRated

  # ~2 calls/sec => up to 200 calls per 5s
  @exrated_bucket :zkb_preloader_provider
  @exrated_interval_ms 5_000
  @exrated_max_requests 200

  @zkillboard_api "https://zkillboard.com/api"

  @doc """
  Perform rate-limit check before fetching a single page from zKillboard and parse the response.

  Returns:
    - `{:ok, updated_state, partials_list}` if success
    - `{:error, reason, updated_state}` if error
  """
  def fetch_and_parse_page(system_id, page, %{calls_count: _n} = state) do
    with :ok <- check_rate(),
         {:ok, resp} <- do_req_get(system_id, page),
         partials when is_list(partials) <- parse_response_body(resp) do
      {:ok, state, partials}
    else
      {:error, :rate_limited} ->
        {:error, :rate_limited, state}

      {:error, reason} ->
        {:error, reason, state}

      _other ->
        {:error, :unexpected, state}
    end
  end

  # -------------------------------------------------------------------
  # Private Helpers
  # -------------------------------------------------------------------
  defp do_req_get(system_id, page) do
    url = "#{@zkillboard_api}/kills/systemID/#{system_id}/page/#{page}/"
    start_ms = System.monotonic_time(:millisecond)

    try do
      resp = Req.get!(url, decode_body: :json)
      _elapsed = System.monotonic_time(:millisecond) - start_ms
      if resp.status == 200 do
        {:ok, resp}
      else
        {:error, {:http_status, resp.status}}
      end
    rescue
      e ->
        Logger.error("""
        [ZkbApi] do_req_get => exception: #{Exception.message(e)}
        stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
        url=#{url}
        """)
        {:error, :exception}
    end
  end

  defp parse_response_body(%{status: 200, body: body}) when is_list(body),
    do: body

  defp parse_response_body(_),
    do: :not_list

  defp check_rate do
    case ExRated.check_rate(@exrated_bucket, @exrated_interval_ms, @exrated_max_requests) do
      {:ok, _count} ->
        :ok

      {:error, limit} ->
        Logger.warning("[ZkbApi] RATE_LIMIT => limit=#{inspect(limit)}")
        {:error, :rate_limited}
    end
  end
end
