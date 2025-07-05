defmodule WandererAppWeb.ProfileLive do
  use WandererAppWeb, :live_view

  require Logger

  alias BetterNumber, as: Number

  def mount(_params, %{"user_id" => user_id} = _session, socket)
      when not is_nil(user_id) do
    WandererApp.Env.map_subscriptions_enabled?()
    |> case do
      true ->
        {:ok, characters} = WandererApp.Api.Character.active_by_user(%{user_id: user_id})

        user =
          user_id
          |> WandererApp.User.load()

        {:ok, user_balance} =
          user
          |> WandererApp.User.get_balance()

        {:ok, latest_transactions} =
          WandererApp.Api.CorpWalletTransaction.latest_by_characters(%{
            eve_character_ids:
              characters
              |> Enum.map(& &1.eve_id)
              |> Enum.map(&String.to_integer/1)
          })

        {:ok, invoices} = WandererApp.Api.MapTransaction.by_user(%{user_id: user_id})

        Phoenix.PubSub.subscribe(
          WandererApp.PubSub,
          "user:#{user_id}"
        )

        {:ok,
         socket
         |> assign(
           wanderer_balance: user_balance,
           characters_count: characters |> Enum.count(),
           user_id: user_id,
           user_hash: user.hash,
           invoices: invoices,
           transactions: latest_transactions
         )}

      _ ->
        {:ok,
         socket
         |> push_navigate(to: ~p"/maps")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(characters_count: 0, user_id: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(
        :wanderer_balance_changed,
        socket
      ) do
    socket =
      case WandererApp.User.load(socket.assigns.current_user.id) do
        nil ->
          socket
          |> assign(:wanderer_balance, 0.0)

        user ->
          socket
          |> assign(:wanderer_balance, user.wanderer_balance)
      end

    {:noreply, socket}
  end

  attr :corporation_id, :any, default: nil
  attr :corporation_info, :any, default: nil

  def corporation_info(assigns) do
    ~H"""
    <div
      :if={@corporation_info}
      class="flex flex-row items-center justify-between gap-2 p-4 bg-stone-950 bg-opacity-70 rounded-lg"
    >
      <div class="avatar">
        <div class="rounded-md w-12 h-12">
          <img
            src={member_icon_url(%{eve_corporation_id: @corporation_id})}
            alt={@corporation_info["name"]}
          />
        </div>
      </div>
      <span>&nbsp; {@corporation_info["name"]}</span>
    </div>
    """
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :profile)
    |> assign(:page_title, "Profile")
  end

  defp apply_action(socket, :deposit, _params) do
    socket
    |> _load_corp_info(WandererApp.Env.corp_eve_id())
    |> assign(:active_page, :profile)
    |> assign(:page_title, "Deposit ISK - Profile")
  end

  defp apply_action(socket, :subscribe, _params) do
    socket
    |> assign(:active_page, :profile)
    |> assign(:page_title, "Subscribe - Profile")
  end

  defp _load_corp_info(socket, -1) do
    socket
    |> assign(:corporation_id, nil)
    |> assign(:corporation_info, nil)
  end

  defp _load_corp_info(socket, corporation_id) do
    case WandererApp.Esi.get_corporation_info(corporation_id) do
      {:ok, corporation_info} ->
        socket
        |> assign(:corporation_id, corporation_id)
        |> assign(:corporation_info, corporation_info)

      error ->
        Logger.warning(fn ->
          "Failed to get corporation info for #{corporation_id}: #{inspect(error)}"
        end)

        socket
        |> assign(:corporation_id, nil)
        |> assign(:corporation_info, nil)
    end
  end
end
