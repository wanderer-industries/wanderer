defmodule WandererAppWeb.UserActivity do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns,
        socket
      ) do
    {:ok,
     socket
     |> handle_info_or_assign(assigns)}
  end

  # attr(:can_undo_types, :list, required: false)
  # attr(:stream, :any, required: true)
  # attr(:page, :integer, required: true)
  # attr(:end_of_stream?, :boolean, required: true)

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <span
        :if={@page > 1}
        class="text-1xl fixed bottom-10 right-10 bg-zinc-700 text-white rounded-lg p-1 text-center min-w-[65px] z-50 opacity-70"
      >
        <%= @page %>
      </span>
      <ul
        id="events"
        class="space-y-4"
        phx-update="stream"
        phx-viewport-top={@page > 1 && "prev-page"}
        phx-viewport-bottom={!@end_of_stream? && "next-page"}
        phx-page-loading
        class={[
          if(@end_of_stream?, do: "pb-10", else: "pb-[calc(200vh)]"),
          if(@page == 1, do: "pt-10", else: "pt-[calc(200vh)]")
        ]}
      >
        <li :for={{dom_id, activity} <- @stream} id={dom_id}>
          <.activity_entry activity={activity} can_undo_types={@can_undo_types} />
        </li>
      </ul>
      <div :if={@end_of_stream?} class="mt-5 text-center">
        No more activity
      </div>
    </div>
    """
  end

  attr(:activity, WandererApp.Api.UserActivity, required: true)
  attr(:can_undo_types, :list, required: false)

  defp activity_entry(%{} = assigns) do
    ~H"""
    <div class="flex items-center w-full space-x-2 p-1 hover:bg-gray-900">
      <div class="flex items-center text-xs w-[270px]">
        <p class="flex items-center space-x-1">
          <span class="w-[150px] line-clamp-1 block text-sm font-normal leading-none text-gray-400 dark:text-gray-500">
            <.local_time id={@activity.id} at={@activity.inserted_at} />
          </span>
        </p>
      </div>

      <.character_item :if={not is_nil(@activity.character)} character={@activity.character} />
      <p :if={is_nil(@activity.character)} class="text-sm text-[var(--color-gray-4)] w-[150px]">
        System user / Administrator
      </p>

      <p class="text-sm text-[var(--color-gray-4)] w-[15%]">
        <%= _get_event_name(@activity.event_type) %>
      </p>
      <.activity_event event_type={@activity.event_type} event_data={@activity.event_data} />

      <div :if={@activity.event_type in @can_undo_types}>
        <button
          phx-click="undo"
          phx-value-event-data={@activity.event_data}
          phx-value-event-type={@activity.event_type}
          class="btn btn-sm btn-icon"
        >
          <.icon name="hero-arrow-uturn-left-solid" class="h-5 w-5" /> Undo
        </button>
      </div>
    </div>
    """
  end

  attr(:character, WandererApp.Api.Character, required: true)

  def character_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-sm w-[150px]">
      <div class="avatar">
        <div class="rounded-md w-8 h-8">
          <img src={member_icon_url(@character.eve_id)} alt={@character.name} />
        </div>
      </div>
      <%= @character.name %>
    </div>
    """
  end

  attr(:event_type, :string, required: true)
  attr(:event_data, :string, required: true)

  def activity_event(assigns) do
    ~H"""
    <div class="w-[40%]">
      <div class="flex items-center gap-1">
        <h6 class="text-base leading-[150%] font-semibold dark:text-white">
          <%= _get_event_data(@event_type, Jason.decode!(@event_data) |> Map.drop(["character_id"])) %>
        </h6>

      </div>
    </div>
    """
  end

  @impl true
  def handle_event("undo", %{"event-data" => event_data} = _params, socket) do
    # notify_to(socket.assigns.notify_to, socket.assigns.event_name, map_slug)
    IO.inspect(event_data)

    {:noreply, socket}
  end

  defp _get_event_name(:hub_added), do: "Hub Added"
  defp _get_event_name(:hub_removed), do: "Hub Removed"
  defp _get_event_name(:map_connection_added), do: "Connection Added"
  defp _get_event_name(:map_connection_updated), do: "Connection Updated"
  defp _get_event_name(:map_connection_removed), do: "Connection Removed"
  defp _get_event_name(:map_acl_added), do: "Acl Added"
  defp _get_event_name(:map_acl_removed), do: "Acl Removed"
  defp _get_event_name(:system_added), do: "System Added"
  defp _get_event_name(:system_updated), do: "System Updated"
  defp _get_event_name(:systems_removed), do: "System(s) Removed"
  defp _get_event_name(name), do: name

  # defp _get_event_data(:hub_added, data), do: Jason.encode!(data)
  # defp _get_event_data(:hub_removed, data), do: data

  # defp _get_event_data(:map_acl_added, data), do: data
  # defp _get_event_data(:map_acl_removed, data), do: data
  # defp _get_event_data(:system_added, data), do: data
  #

  defp _get_event_data(:system_updated, %{
         "key" => "labels",
         "solar_system_id" => solar_system_id,
         "value" => value
       }) do
    system_name = _get_system_name(solar_system_id)

    try do
      %{"customLabel" => customLabel, "labels" => labels} = Jason.decode!(value)

      "#{system_name} labels - #{inspect(labels)}, customLabel - #{customLabel}"
    rescue
      _ ->
        "#{system_name} labels - #{inspect(value)}"
    end
  end

  defp _get_event_data(:system_added, %{
         "solar_system_id" => solar_system_id
       }),
       do: _get_system_name(solar_system_id)

  defp _get_event_data(:hub_added, %{
         "solar_system_id" => solar_system_id
       }),
       do: _get_system_name(solar_system_id)

  defp _get_event_data(:hub_removed, %{
         "solar_system_id" => solar_system_id
       }),
       do: _get_system_name(solar_system_id)

  defp _get_event_data(:system_updated, %{
         "key" => key,
         "solar_system_id" => solar_system_id,
         "value" => value
       }) do
    system_name = _get_system_name(solar_system_id)
    "#{system_name} #{key} - #{inspect(value)}"
  end

  defp _get_event_data(:systems_removed, %{
         "solar_system_ids" => solar_system_ids
       }),
       do:
         solar_system_ids
         |> Enum.map(&_get_system_name/1)
         |> Enum.join(", ")

  defp _get_event_data(:map_connection_added, %{
         "solar_system_source_id" => solar_system_source_id,
         "solar_system_target_id" => solar_system_target_id
       }) do
    source_system_name = _get_system_name(solar_system_source_id)
    target_system_name = _get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}]"
  end

  defp _get_event_data(:map_connection_removed, %{
         "solar_system_source_id" => solar_system_source_id,
         "solar_system_target_id" => solar_system_target_id
       }) do
    source_system_name = _get_system_name(solar_system_source_id)
    target_system_name = _get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}]"
  end

  defp _get_event_data(:map_connection_updated, %{
         "key" => key,
         "solar_system_source_id" => solar_system_source_id,
         "solar_system_target_id" => solar_system_target_id,
         "value" => value
       }) do
    source_system_name = _get_system_name(solar_system_source_id)
    target_system_name = _get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}] #{key} - #{inspect(value)}"
  end

  defp _get_event_data(_name, data), do: Jason.encode!(data)

  defp _get_system_name(solar_system_id) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, nil} ->
        solar_system_id

      {:ok, system_static_info} ->
        Map.get(system_static_info, :solar_system_name, "")

      _ ->
        ""
    end
  end
end
