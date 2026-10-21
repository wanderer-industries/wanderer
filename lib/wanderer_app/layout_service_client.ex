defmodule WandererApp.LayoutServiceClient do
  @moduledoc """
  HTTP client for the optional graph layout service.
  """

  require Logger

  @timeout_opts [pool_timeout: 5_000, receive_timeout: :timer.seconds(20)]

  def layout(payload) do
    if WandererApp.Env.layout_service_enabled?() do
      url = "#{WandererApp.Env.layout_service_base_url()}/v1/layout"

      case Req.post(url, Keyword.merge([json: payload], @timeout_opts)) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("[LayoutServiceClient] Unexpected status #{status}: #{inspect(body)}")
          {:error, {:unexpected_status, status, body}}

        {:error, reason} ->
          Logger.error("[LayoutServiceClient] Request failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :disabled}
    end
  end
end
