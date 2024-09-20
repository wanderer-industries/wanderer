defmodule WandererAppWeb.UserActivity do
  use WandererAppWeb, :live_component

  attr(:stream, :any, required: true)
  attr(:page, :integer, required: true)
  attr(:end_of_stream?, :boolean, required: true)

  def list(assigns) do
    ~H"""
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
        <.activity_entry activity={activity} />
      </li>
    </ul>
    <div :if={@end_of_stream?} class="mt-5 text-center">
      No more activity
    </div>
    """
  end

  attr(:activity, WandererApp.Api.UserActivity, required: true)

  defp activity_entry(%{} = assigns) do
    ~H"""
    <div class="flex w-full items-center justify-between space-x-2">
      <div class="flex items-center space-x-3 text-xs">
        <p class="flex items-center space-x-1">
          <span class="w-[150px] line-clamp-1 block text-sm font-normal leading-none text-gray-400 dark:text-gray-500">
            <.local_time id={@activity.id} at={@activity.inserted_at} />
          </span>
        </p>
        <p :if={not is_nil(@activity.character)} class="flex shrink-0 items-center space-x-1 min-w-[200px]">
          <.character_item character={@activity.character} />
        </p>
      </div>
      <p class="text-sm leading-[150%] text-[var(--color-gray-4)]">
        <%= _get_event_name(@activity.event_type) %>
      </p>
      <.activity_event event_type={@activity.event_type} event_data={@activity.event_data} />
    </div>
    """
  end

  attr(:character, WandererApp.Api.Character, required: true)

  def character_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-sm">
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
