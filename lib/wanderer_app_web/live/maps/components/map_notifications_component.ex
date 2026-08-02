defmodule WandererAppWeb.MapNotificationsComponent do
  @moduledoc """
  Settings tab for per-map Discord kill notifications.

  The webhook URL is a credential: it is stored encrypted and only ever shown
  as a masked hint, with a replace flow, like a password field.
  """

  use WandererAppWeb, :live_component

  alias WandererApp.Api.MapDiscordNotification
  alias WandererApp.Api.MapSolarSystem

  @live_select_id "excluded_system_live_select_component"
  @min_search_length 2
  @max_search_results 20

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    notification =
      case MapDiscordNotification.by_map(map_id) do
        {:ok, rec} -> rec
        _ -> nil
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:live_select_id, @live_select_id)
     |> assign(:min_search_length, @min_search_length)
     |> assign_new(:system_options, fn -> [] end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:flash_message, fn -> nil end)
     |> assign_new(:replacing_url?, fn -> is_nil(notification) end)
     |> assign_notification(notification)}
  end

  @impl true
  def handle_event("save", %{"notification" => params}, socket) do
    # `.input type="checkbox"` renders a hidden "false" before the box, so a
    # rendered field always submits a value and Phoenix keeps the last one.
    attrs = %{
      wh_only: checked?(params["wh_only"]),
      enabled?: checked?(params["enabled"])
    }

    result =
      case {socket.assigns.notification, params["webhook_url"]} do
        {nil, url} ->
          MapDiscordNotification.create(
            Map.merge(attrs, %{map_id: socket.assigns.map_id, webhook_url: url})
          )

        {rec, url} when is_binary(url) and url != "" ->
          MapDiscordNotification.update(rec, Map.put(attrs, :webhook_url, url))

        {rec, _} ->
          MapDiscordNotification.update(rec, attrs)
      end

    case result do
      {:ok, rec} ->
        {:noreply,
         socket
         |> assign_notification(rec)
         |> assign(:replacing_url?, false)
         |> assign(:error, nil)
         |> assign(:flash_message, "Saved.")}

      {:error, error} ->
        {:noreply, socket |> assign(:error, humanize_error(error)) |> assign(:flash_message, nil)}
    end
  end

  def handle_event("replace-url", _params, socket) do
    {:noreply, assign(socket, :replacing_url?, true)}
  end

  # LiveSelect's search callback: users know systems by name, not by numeric id.
  #
  # This must be handled HERE and not by the parent LiveView, whose own
  # `live_select_change` handler answers unconditionally with access-list
  # options. `phx-target={@myself}` on the live_select is what keeps the event
  # in this component.
  def handle_event("live_select_change", %{"id" => id, "text" => text}, socket) do
    options = search_systems(text)

    send_update(LiveSelect.Component, id: id, options: options)

    {:noreply, assign(socket, :system_options, options)}
  end

  def handle_event("add-excluded", %{"excluded" => %{"excluded_system" => raw}}, socket) do
    with %{} = rec <- socket.assigns.notification,
         {id, ""} <- Integer.parse(to_string(raw)) do
      update_excluded(socket, rec, Enum.uniq([id | rec.excluded_systems]))
    else
      _ -> {:noreply, assign(socket, :error, "Pick a system from the list.")}
    end
  end

  # Guarded the same way as `add-excluded`: only reachable from a rendered
  # button today, but the two handlers should not disagree about whether a
  # missing record or a non-numeric id is survivable.
  def handle_event("remove-excluded", %{"system_id" => raw}, socket) do
    with %{} = rec <- socket.assigns.notification,
         {id, ""} <- Integer.parse(to_string(raw)) do
      update_excluded(socket, rec, Enum.reject(rec.excluded_systems, &(&1 == id)))
    else
      _ -> {:noreply, assign(socket, :error, "Could not remove that system.")}
    end
  end

  def handle_event("send-test", _params, socket) do
    case WandererApp.ExternalEvents.DiscordDispatcher.send_test_message(socket.assigns.map_id) do
      # `:ok` means the message was ENQUEUED — the last hop is an async cast, so
      # this must not claim Discord accepted it.
      :ok ->
        {:noreply,
         socket |> assign(:flash_message, "Test message queued.") |> assign(:error, nil)}

      {:error, :notifications_disabled} ->
        {:noreply,
         socket
         |> assign(
           :error,
           "Discord notifications are disabled on this server. Ask an administrator to enable them."
         )
         |> assign(:flash_message, nil)}

      {:error, :not_configured} ->
        {:noreply,
         socket |> assign(:error, "Save a webhook URL first.") |> assign(:flash_message, nil)}

      {:error, other} ->
        {:noreply,
         socket
         |> assign(:error, "Could not send a test message: #{inspect(other)}")
         |> assign(:flash_message, nil)}
    end
  end

  def handle_event("delete", _params, socket) do
    case socket.assigns.notification do
      nil ->
        {:noreply, socket}

      rec ->
        # The resource's custom destroy invalidates the config cache and stops
        # the map's delivery worker; nothing extra to do here.
        case Ash.destroy(rec) do
          :ok ->
            {:noreply,
             socket
             |> assign_notification(nil)
             |> assign(:replacing_url?, true)
             |> assign(:error, nil)
             |> assign(:flash_message, "Removed.")}

          {:error, error} ->
            {:noreply,
             socket |> assign(:error, humanize_error(error)) |> assign(:flash_message, nil)}
        end
    end
  end

  defp update_excluded(socket, rec, excluded) do
    case MapDiscordNotification.update(rec, %{excluded_systems: excluded}) do
      {:ok, updated} ->
        {:noreply, socket |> assign_notification(updated) |> assign(:error, nil)}

      {:error, error} ->
        {:noreply, assign(socket, :error, humanize_error(error))}
    end
  end

  # Resolves the excluded systems' names once per change, not once per render:
  # this runs a query, and the template re-renders on every live_select
  # keystroke. Also rebuilds the forms so their values follow the record.
  defp assign_notification(socket, notification) do
    socket
    |> assign(:notification, notification)
    |> assign(:excluded_systems, excluded_system_labels(notification))
    |> assign(:form, notification_form(notification))
    |> assign(:excluded_form, to_form(%{"excluded_system" => nil}, as: :excluded))
  end

  defp notification_form(notification) do
    to_form(
      %{
        "webhook_url" => "",
        "wh_only" => is_nil(notification) or notification.wh_only,
        "enabled" => is_nil(notification) or notification.enabled?
      },
      as: :notification
    )
  end

  # Mirrors the ACL live_select pattern in maps_live: search server-side, feed
  # `{label, value}` options back into the component.
  defp search_systems(text) when is_binary(text) and byte_size(text) >= @min_search_length do
    case MapSolarSystem.find_by_name(%{name: text}) do
      {:ok, systems} ->
        systems
        |> Enum.take(@max_search_results)
        |> Enum.map(&{"#{&1.solar_system_name} (#{&1.region_name})", &1.solar_system_id})

      _ ->
        []
    end
  end

  defp search_systems(_), do: []

  # One query for every excluded system, not one per system. Falls back to the
  # bare id for anything the lookup did not return, and keeps the stored order.
  defp excluded_system_labels(nil), do: []
  defp excluded_system_labels(%{excluded_systems: []}), do: []

  defp excluded_system_labels(%{excluded_systems: ids}) do
    labels =
      case MapSolarSystem.by_solar_system_ids(ids) do
        {:ok, systems} ->
          Map.new(
            systems,
            &{&1.solar_system_id, "#{&1.solar_system_name} (#{&1.solar_system_id})"}
          )

        _ ->
          %{}
      end

    Enum.map(ids, &{&1, Map.get(labels, &1, to_string(&1))})
  end

  defp checked?("true"), do: true
  defp checked?(true), do: true
  defp checked?(_), do: false

  defp humanize_error(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ", ", fn
      %{message: message} when is_binary(message) -> message
      other -> inspect(other)
    end)
  end

  defp humanize_error(other), do: inspect(other)

  defp masked_url(nil), do: ""

  defp masked_url(url) when is_binary(url) do
    case String.split(url, "/", trim: true) do
      parts when length(parts) >= 2 ->
        [token, id | _] = Enum.reverse(parts)
        ".../#{id}/#{String.slice(token, 0, 4)}••••"

      _ ->
        "••••"
    end
  end

  defp masked_url(_), do: "••••"

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-4">
      <p class="text-sm opacity-70">
        Posts kills for systems on this map to a Discord channel.
        These filters are separate from the Kills widget's own filters,
        which are per-user and only affect what you see in the map UI.
      </p>

      <p :if={@error} class="text-sm text-red-400">{@error}</p>
      <p :if={@flash_message} class="text-sm text-green-400">{@flash_message}</p>

      <.form
        :let={f}
        for={@form}
        id="discord-notification-form"
        phx-submit="save"
        phx-target={@myself}
        class="flex flex-col gap-3"
      >
        <.input
          :if={@replacing_url?}
          field={f[:webhook_url]}
          type="password"
          label="Discord webhook URL"
          placeholder="https://discord.com/api/webhooks/..."
          autocomplete="off"
        />

        <div :if={!@replacing_url? && @notification} class="flex items-center gap-2">
          <span class="text-sm opacity-70">URL: {masked_url(@notification.webhook_url)}</span>
          <.button type="button" phx-click="replace-url" phx-target={@myself}>
            Replace
          </.button>
        </div>

        <.input field={f[:wh_only]} type="checkbox" label="Only wormhole kills" />
        <.input field={f[:enabled]} type="checkbox" label="Enabled" />

        <.button type="submit">Save</.button>
      </.form>

      <div :if={@notification} class="flex flex-col gap-2">
        <h4 class="text-sm font-semibold">Excluded systems</h4>

        <ul class="flex flex-col gap-1">
          <li :for={{system_id, label} <- @excluded_systems} class="flex items-center gap-2 text-sm">
            <span>{label}</span>
            <.button
              type="button"
              phx-click="remove-excluded"
              phx-value-system_id={system_id}
              phx-target={@myself}
            >
              Remove
            </.button>
          </li>
        </ul>

        <.form
          :let={ef}
          for={@excluded_form}
          id="excluded-system-form"
          phx-submit="add-excluded"
          phx-target={@myself}
          class="grid items-end gap-2"
          style="grid-template-columns: 1fr auto"
        >
          <.live_select
            field={ef[:excluded_system]}
            id={@live_select_id}
            phx-target={@myself}
            dropdown_extra_class="!h-24"
            debounce={250}
            update_min_len={@min_search_length}
            mode={:single}
            options={@system_options}
            placeholder="Search a system by name"
          />
          <.button type="submit">Add</.button>
        </.form>
      </div>

      <div :if={@notification} class="flex items-center gap-2">
        <.button type="button" phx-click="send-test" phx-target={@myself}>
          Send test message
        </.button>
        <.button
          type="button"
          class="btn-error"
          phx-click="delete"
          phx-target={@myself}
          data-confirm="Remove Discord notifications for this map?"
        >
          Remove
        </.button>
      </div>

      <div :if={@notification} class="flex flex-col gap-1 text-sm">
        <span :if={@notification.last_delivery_at} class="opacity-70">
          Last delivered: {Calendar.strftime(@notification.last_delivery_at, "%Y-%m-%d %H:%M UTC")}
        </span>
        <span :if={is_nil(@notification.last_delivery_at)} class="opacity-70">
          No kills delivered yet.
        </span>

        <span :if={@notification.last_error} class="text-amber-400">
          Last error: {@notification.last_error}
          <span :if={@notification.consecutive_failures > 0}>
            ({@notification.consecutive_failures} consecutive failures)
          </span>
        </span>
      </div>
    </div>
    """
  end
end
