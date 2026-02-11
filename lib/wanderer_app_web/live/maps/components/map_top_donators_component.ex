defmodule WandererAppWeb.Maps.MapTopDonatorsComponent do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  require Logger

  alias BetterNumber, as: Number

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket, top_donators: [], period: "all", image_base_url: "https://images.evetech.net")}
  end

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    socket = handle_info_or_assign(socket, assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(map_id: map_id)
      |> load_top_donators()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    socket =
      socket
      |> assign(period: period)
      |> load_top_donators()

    {:noreply, socket}
  end

  defp load_top_donators(%{assigns: %{map_id: map_id, period: period}} = socket) do
    after_date = period_to_date(period)

    case WandererApp.Api.MapTransaction.top_donators(%{map_id: map_id, after: after_date}) do
      {:ok, donators} ->
        enriched = enrich_with_characters(donators)
        assign(socket, top_donators: enriched)

      {:error, reason} ->
        Logger.warning("Failed to load top donators: #{inspect(reason)}")
        assign(socket, top_donators: [])
    end
  end

  defp period_to_date("all"), do: nil
  defp period_to_date("30d"), do: DateTime.utc_now() |> DateTime.add(-30, :day)
  defp period_to_date("7d"), do: DateTime.utc_now() |> DateTime.add(-7, :day)
  defp period_to_date(_), do: nil

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="map-top-donators">
      <div class="flex gap-2 mb-4">
        <button
          type="button"
          class={[
            "btn btn-sm",
            if(@period == "all", do: "btn-primary", else: "btn-ghost")
          ]}
          phx-click="change_period"
          phx-value-period="all"
          phx-target={@myself}
        >
          All Time
        </button>
        <button
          type="button"
          class={[
            "btn btn-sm",
            if(@period == "30d", do: "btn-primary", else: "btn-ghost")
          ]}
          phx-click="change_period"
          phx-value-period="30d"
          phx-target={@myself}
        >
          30 Days
        </button>
        <button
          type="button"
          class={[
            "btn btn-sm",
            if(@period == "7d", do: "btn-primary", else: "btn-ghost")
          ]}
          phx-click="change_period"
          phx-value-period="7d"
          phx-target={@myself}
        >
          7 Days
        </button>
      </div>

      <div :if={@top_donators == []} class="text-center text-gray-400 py-8">
        No donations found for this period.
      </div>

      <div :if={@top_donators != []} class="space-y-2">
        <div
          :for={{donator, index} <- Enum.with_index(@top_donators)}
          class="flex items-center gap-3 p-2 rounded-lg bg-base-200/50"
        >
          <span class="text-lg font-bold text-gray-400 w-6 text-right">
            {index + 1}
          </span>
          <img
            src={"#{@image_base_url}/characters/#{donator.eve_id}/portrait?size=64"}
            class="w-10 h-10 rounded-full"
            alt={donator.character_name}
          />
          <div class="flex-1 min-w-0">
            <div class="font-medium text-white truncate">
              {donator.character_name}
            </div>
            <div :if={donator.corporation_name} class="text-xs text-gray-400 truncate">
              [{donator.corporation_ticker}] {donator.corporation_name}
            </div>
          </div>
          <div class="text-right font-mono text-sm text-green-400">
            ISK {donator.total_amount |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
