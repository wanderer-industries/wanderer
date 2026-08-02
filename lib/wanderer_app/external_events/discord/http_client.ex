defmodule WandererApp.ExternalEvents.Discord.HttpClient do
  @moduledoc """
  Seam over HTTP delivery to Discord, so dispatch logic can be tested without
  a live endpoint. The real implementation uses an isolated Finch pool.
  """

  @callback post(url :: String.t(), body :: map()) ::
              {:ok, status :: integer(), headers :: list()} | {:error, term()}

  @doc "Returns the configured implementation module."
  def impl do
    Application.get_env(
      :wanderer_app,
      :discord_http_client,
      WandererApp.ExternalEvents.Discord.HttpClient.Finch
    )
  end

  @doc "Posts a Discord message body, delegating to the configured implementation."
  def post(url, body), do: impl().post(url, body)

  defmodule Finch do
    @moduledoc "Real HTTP delivery via the isolated Discord Finch pool."
    @behaviour WandererApp.ExternalEvents.Discord.HttpClient

    @timeout 15_000

    @impl true
    def post(url, body) do
      headers = [{"content-type", "application/json"}]

      case Jason.encode(body) do
        {:ok, json} ->
          :post
          |> Elixir.Finch.build(url, headers, json)
          |> Elixir.Finch.request(WandererApp.Finch.Discord, receive_timeout: @timeout)
          |> case do
            {:ok, %Elixir.Finch.Response{status: status, headers: resp_headers}} ->
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
