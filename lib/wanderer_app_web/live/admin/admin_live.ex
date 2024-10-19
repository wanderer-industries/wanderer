defmodule WandererAppWeb.AdminLive do
  use WandererAppWeb, :live_view

  require Logger
  alias BetterNumber, as: Number

  @invite_link_ttl :timer.hours(24)

  def mount(_params, %{"user_id" => user_id} = _session, socket)
      when not is_nil(user_id) do
    WandererApp.StartCorpWalletTrackerTask.maybe_start_corp_wallet_tracker(
      {:ok, socket.assigns.current_user.characters}
    )

    corp_wallet_character =
      socket.assigns.current_user.characters
      |> Enum.find(fn character ->
        WandererApp.Character.can_track_corp_wallet?(character)
      end)

    Phoenix.PubSub.subscribe(
      WandererApp.PubSub,
      "corporation"
    )

    user_character_ids = socket.assigns.current_user.characters |> Enum.map(& &1.id)

    user_character_ids
    |> Enum.each(fn user_character_id ->
      :ok = WandererApp.Character.TrackerManager.start_tracking(user_character_id)
    end)

    socket =
      if not is_nil(corp_wallet_character) do
        {:ok, total_balance} =
          WandererApp.Character.TransactionsTracker.get_total_balance(corp_wallet_character.id)

        {:ok, transactions} =
          WandererApp.Character.TransactionsTracker.get_transactions(corp_wallet_character.id)

        socket
        |> assign(
          total_balance: total_balance,
          transactions: transactions
        )
      else
        socket
        |> assign(
          total_balance: 0,
          transactions: []
        )
      end

    {:ok, active_map_subscriptions} =
      WandererApp.Api.MapSubscription.all_active()

    {:ok,
     socket
     |> assign(
       active_map_subscriptions: active_map_subscriptions,
       show_invites?: WandererApp.Env.invites(),
       user_character_ids: user_character_ids,
       user_id: user_id,
       invite_link: nil,
       map_subscriptions_enabled?: WandererApp.Env.map_subscriptions_enabled?()
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(user_id: nil)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params, uri)}
  end

  def handle_event("generate-invite-link", _params, socket) do
    uuid = UUID.uuid4(:default)
    WandererApp.Cache.put("invite_#{uuid}", true, ttl: @invite_link_ttl)

    invite_link =
      socket.assigns.uri
      |> Map.put(:path, "/welcome")
      |> Map.put(:query, URI.encode_query(%{invite: uuid}))
      |> URI.to_string()

    {:noreply,
     socket
     |> assign(invite_link: invite_link)}
  end

  @impl true
  def handle_event("update-eve-db-data", _params, socket) do
    WandererApp.EveDataService.update_eve_data()
    {:noreply, socket |> put_flash(:info, "EVE Data updated. Please restart server.")}
  end

  @impl true
  def handle_event("authorize", _params, socket) do
    token = UUID.uuid4(:default)
    WandererApp.Cache.put("invite_#{token}", true, ttl: :timer.minutes(30))

    {:noreply, socket |> push_navigate(to: ~p"/auth/eve?invite=#{token}&admin=true")}
  end

  @impl true
  def handle_event(
        "live_select_change",
        %{"id" => "_character_id_live_select_component" = id, "text" => text} = _change_event,
        socket
      ) do
    options =
      if text == "" do
        []
      else
        DebounceAndThrottle.Debounce.apply(
          Process,
          :send_after,
          [self(), {:search, text}, 100],
          "character_search",
          500
        )

        [%{label: "Loading...", value: :loading, disabled: true}]
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply,
     socket
     |> assign(
       character_search_options: options,
       character_search_text: text,
       character_search_id: id
     )}
  end

  @impl true
  def handle_event(
        "live_select_change",
        %{"id" => "_unlink_character_id_live_select_component" = id, "text" => text} =
          _change_event,
        socket
      ) do
    options =
      if text == "" do
        []
      else
        DebounceAndThrottle.Debounce.apply(
          Process,
          :send_after,
          [self(), {:search, text}, 100],
          "character_search",
          500
        )

        [%{label: "Loading...", value: :loading, disabled: true}]
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply,
     socket
     |> assign(
       character_search_options: options,
       character_search_text: text,
       character_search_id: id
     )}
  end

  @impl true
  def handle_event(
        "update-balance",
        %{"amount" => amount, "character_id" => character_id} = _form,
        socket
      ) do
    {:ok, %{user: user}} = WandererApp.Api.Character.by_id!(character_id) |> Ash.load([:user])

    {:ok, _user} =
      user
      |> WandererApp.Api.User.update_balance(%{
        balance: String.to_integer(amount)
      })

    {:noreply,
     socket
     |> put_flash(:info, "User balance updated.")}
  end

  @impl true
  def handle_event(
        "unlink-character",
        %{"unlink_character_id" => character_id} = _form,
        socket
      ) do
    character =
      character_id
      |> WandererApp.Api.Character.by_id!()

    character
    |> WandererApp.Api.Character.mark_as_deleted!()

    {:noreply,
     socket
     |> put_flash(:info, "Character unlinked.")}
  end

  @impl true
  def handle_event(event, body, socket) do
    Logger.warning(fn -> "unhandled event: #{event} #{inspect(body)}" end)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:total_balance_changed, _corporation_id, total_balance},
        socket
      ) do
    {:noreply, socket |> assign(total_balance: total_balance)}
  end

  @impl true
  def handle_info(
        {:transactions, _corporation_id, transactions},
        socket
      ) do
    {:noreply, socket |> assign(transactions: transactions)}
  end

  @impl true
  def handle_info({:search, text}, socket) do
    {:ok, options} = search(text)

    send_update(LiveSelect.Component, options: options, id: socket.assigns.character_search_id)
    {:noreply, socket |> assign(character_search_options: options)}
  end

  defp apply_action(socket, :index, _params, uri) do
    socket
    |> assign(:active_page, :admin)
    |> assign(:uri, URI.parse(uri))
    |> assign(:page_title, "Administration")
    |> assign(:character_search_options, [])
    |> assign(:amounts, [
      %{label: "500M", value: 500_000_000},
      %{label: "1B", value: 1_000_000_000},
      %{label: "5B", value: 5_000_000_000},
      %{label: "10B", value: 10_000_000_000}
    ])
    |> assign(:form, to_form(%{"amount" => 500_000_000}))
    |> assign(:unlink_character_form, to_form(%{}))
  end

  defp search(search) do
    {:ok, characters} = WandererApp.Api.Character.search_by_name(%{name: search})
    {:ok, characters |> Enum.map(&map_character/1)}
  end

  defp map_character(%{name: name, id: id, eve_id: eve_id} = _character) do
    %{label: name, value: id, id: id, eve_id: eve_id}
  end

  attr :option, :any, required: true

  def search_member_item(assigns) do
    ~H"""
    <div class="flex items-center">
      <div :if={@option.value != :loading} class="avatar">
        <div class="rounded-md w-12 h-12">
          <img src={search_member_icon_url(@option)} alt={@option.label} />
        </div>
      </div>
      <span :if={@option.value == :loading} <span class="loading loading-spinner loading-xs"></span>
      &nbsp; <%= @option.label %>
    </div>
    """
  end

  def search_member_icon_url(%{character: true} = option),
    do: member_icon_url(%{eve_character_id: option.value})

  def search_member_icon_url(%{corporation: true} = option),
    do: member_icon_url(%{eve_corporation_id: option.value})

  def search_member_icon_url(%{alliance: true} = option),
    do: member_icon_url(%{eve_alliance_id: option.value})

  def search_member_icon_url(%{eve_id: eve_id} = _option),
    do: member_icon_url(%{eve_character_id: eve_id})
end
