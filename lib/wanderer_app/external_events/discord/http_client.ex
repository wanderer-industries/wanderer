defmodule WandererApp.ExternalEvents.Discord.HttpClient do
  @moduledoc """
  Seam over HTTP delivery to Discord, so dispatch logic can be tested without
  a live endpoint. The real implementation uses an isolated Finch pool.

  A response-driven global cooldown is shared on the configured delivery node.
  Discord webhook requests have no Authorization header, so Discord's global
  limit applies to their source IP. This is not a proactive requests/second
  limiter, nor coordination with other applications or nodes sharing that IP.
  Cooldown state is in memory and is lost if its supervised cache restarts.
  Requests already in flight when a global 429 arrives cannot be recalled.
  """

  @callback post(url :: String.t(), body :: map()) ::
              {:ok, status :: integer(), headers :: list()}
              | {:ok, 429, headers :: list(), body :: String.t()}
              | {:error, term()}

  @rate_limit_cache :discord_rate_limit_cache
  @global_retry_at :global_retry_at
  @min_retry_after_ms 50
  @default_retry_after_ms 1_000

  @doc "Returns the configured implementation module."
  def impl do
    Application.get_env(
      :wanderer_app,
      :discord_http_client,
      WandererApp.ExternalEvents.Discord.HttpClient.Live
    )
  end

  @doc """
  Posts through the configured implementation, unless a known global cooldown
  is active. In that case no network call is made and the existing typed
  `{:ok, 429, headers}` result is returned: `retry-after` contains remaining
  seconds, `x-ratelimit-global` is `true`, and `x-ratelimit-scope` is `global`.
  These synthetic headers use the same units/meaning as Discord's response.
  """
  def post(url, body) do
    case global_cooldown_ms() do
      ms when ms > 0 ->
        {:ok, 429,
         [
           {"retry-after", to_string(ms / 1000)},
           {"x-ratelimit-global", "true"},
           {"x-ratelimit-scope", "global"}
         ]}

      _ ->
        case impl().post(url, body) do
          {:error, {:encode_failed, _reason}} -> {:error, {:encode_failed, :invalid_payload}}
          {:error, _reason} -> {:error, :connection_error}
          response -> observe_rate_limit(response)
        end
    end
  rescue
    # Transport exceptions can carry the full request target (the webhook
    # credential). Do not let them reach task crash logs or persisted status.
    _ -> {:error, :connection_error}
  catch
    :exit, _ -> {:error, :connection_error}
  end

  @doc "Remaining node-local global cooldown, shared by every map worker."
  def global_cooldown_ms do
    case Cachex.get(@rate_limit_cache, @global_retry_at) do
      {:ok, retry_at} when is_integer(retry_at) ->
        max(retry_at - System.monotonic_time(:millisecond), 0)

      _ ->
        0
    end
  end

  @doc false
  def retry_after_ms(headers, body \\ nil) do
    value =
      case decode_body(body) do
        %{"retry_after" => seconds} when is_number(seconds) and seconds >= 0 -> seconds
        _ -> header(headers, "retry-after")
      end

    case Float.parse(to_string(value)) do
      {seconds, ""} when seconds >= 0 ->
        max(ceil(seconds * 1000), @min_retry_after_ms)

      _ ->
        @default_retry_after_ms
    end
  end

  defp observe_rate_limit({:ok, 429, headers, body} = response) do
    remember_global_cooldown(headers, body)
    response
  end

  defp observe_rate_limit({:ok, 429, headers} = response) do
    remember_global_cooldown(headers, nil)
    response
  end

  defp observe_rate_limit(response), do: response

  defp remember_global_cooldown(headers, body) do
    if header(headers, "x-ratelimit-global") == "true" or
         header(headers, "x-ratelimit-scope") == "global" or
         decode_body(body)["global"] == true do
      retry_at = System.monotonic_time(:millisecond) + retry_after_ms(headers, body)

      # Lock the shared key: a concurrent shorter 429 must never overwrite a
      # longer deadline. One fixed key, no webhook URLs or tokens in the cache.
      Cachex.transaction(@rate_limit_cache, [@global_retry_at], fn cache ->
        {:ok, previous} = Cachex.get(cache, @global_retry_at)
        retry_at = if is_integer(previous), do: max(previous, retry_at), else: retry_at
        Cachex.put(cache, @global_retry_at, retry_at)
      end)
    end
  end

  defp header(headers, name) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(key) == name, do: value
    end)
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> %{}
    end
  end

  defp decode_body(_), do: %{}

  defmodule Live do
    @moduledoc """
    Real HTTP delivery via the isolated Discord Finch pool.

    Named `Live` rather than `Finch` so the nested module does not shadow the
    Finch library inside its own body.
    """
    @behaviour WandererApp.ExternalEvents.Discord.HttpClient

    @timeout 15_000

    @impl true
    def post(url, body) do
      headers = [{"content-type", "application/json"}]

      case Jason.encode(body) do
        {:ok, json} ->
          :post
          |> Finch.build(url, headers, json)
          |> Finch.request(WandererApp.Finch.Discord, receive_timeout: @timeout)
          |> case do
            {:ok, %Finch.Response{status: 429, headers: resp_headers, body: body}} ->
              {:ok, 429, resp_headers, body}

            {:ok, %Finch.Response{status: status, headers: resp_headers}} ->
              {:ok, status, resp_headers}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, {:encode_failed, reason}}
      end
    end
  end
end
