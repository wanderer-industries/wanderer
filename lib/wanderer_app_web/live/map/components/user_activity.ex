defmodule WandererAppWeb.UserActivity do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(
        assigns,
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
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <ul id="events" class="space-y-4" phx-update="stream" phx-page-loading class={["pt-10"]}>
        <li :for={{dom_id, activity} <- @stream} id={dom_id}>
          <.activity_entry activity={activity} can_undo_types={@can_undo_types} />
        </li>
      </ul>
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
        {get_event_name(@activity.event_type)}
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
      {@character.name}
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
          {get_event_data(@event_type, Jason.decode!(@event_data) |> Map.drop(["character_id"]))}
        </h6>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("undo", %{"event-data" => _event_data} = _params, socket) do
    # notify_to(socket.assigns.notify_to, socket.assigns.event_name, map_slug)

    {:noreply, socket}
  end

  def get_event_name(:hub_added), do: "Hub Added"
  def get_event_name(:hub_removed), do: "Hub Removed"
  def get_event_name(:map_connection_added), do: "Connection Added"
  def get_event_name(:map_connection_updated), do: "Connection Updated"
  def get_event_name(:map_connection_removed), do: "Connection Removed"
  def get_event_name(:map_acl_added), do: "Acl Added"
  def get_event_name(:map_acl_removed), do: "Acl Removed"
  def get_event_name(:system_added), do: "System Added"
  def get_event_name(:system_updated), do: "System Updated"
  def get_event_name(:systems_removed), do: "System(s) Removed"
  def get_event_name(:signatures_added), do: "Signatures Added"
  def get_event_name(:signatures_removed), do: "Signatures Removed"
  def get_event_name(:map_rally_added), do: "Rally Point Added"
  def get_event_name(:map_rally_cancelled), do: "Rally Point Cancelled"
  def get_event_name(name), do: name

  def get_event_data(:map_acl_added, %{"acl_id" => acl_id}) do
    {:ok, acl} = WandererApp.AccessListRepo.get(acl_id)
    "#{acl.name}"
  end

  def get_event_data(:map_acl_removed, %{"acl_id" => acl_id}) do
    {:ok, acl} = WandererApp.AccessListRepo.get(acl_id)
    "#{acl.name}"
  end

  # defp get_event_data(:map_acl_removed, data), do: data
  # defp get_event_data(:system_added, data), do: data
  #

  def get_event_data(:system_updated, %{
        "key" => "labels",
        "solar_system_id" => solar_system_id,
        "value" => value
      }) do
    system_name = get_system_name(solar_system_id)

    try do
      %{"customLabel" => customLabel, "labels" => labels} = Jason.decode!(value)

      "#{system_name}: labels - #{inspect(labels)}, customLabel - #{customLabel}"
    rescue
      _ ->
        "#{system_name}: labels - #{inspect(value)}"
    end
  end

  def get_event_data(:system_added, %{
        "solar_system_id" => solar_system_id
      }),
      do: get_system_name(solar_system_id)

  def get_event_data(:hub_added, %{
        "solar_system_id" => solar_system_id
      }),
      do: get_system_name(solar_system_id)

  def get_event_data(:hub_removed, %{
        "solar_system_id" => solar_system_id
      }),
      do: get_system_name(solar_system_id)

  def get_event_data(:system_updated, %{
        "key" => key,
        "solar_system_id" => solar_system_id,
        "value" => value
      }) do
    system_name = get_system_name(solar_system_id)
    "#{system_name}: #{key} - #{inspect(value)}"
  end

  def get_event_data(:systems_removed, %{
        "solar_system_ids" => solar_system_ids
      }),
      do:
        solar_system_ids
        |> Enum.map(&get_system_name/1)
        |> Enum.join(", ")

  def get_event_data(signatures_event, %{
        "solar_system_id" => solar_system_id,
        "signatures" => signatures
      })
      when signatures_event in [:signatures_added, :signatures_removed],
      do: "#{get_system_name(solar_system_id)}: #{signatures |> Enum.join(", ")}"

  def get_event_data(signatures_event, %{
        "signatures" => signatures
      })
      when signatures_event in [:signatures_added, :signatures_removed],
      do: signatures |> Enum.join(", ")

  def get_event_data(:map_connection_added, %{
        "solar_system_source_id" => solar_system_source_id,
        "solar_system_target_id" => solar_system_target_id
      }) do
    source_system_name = get_system_name(solar_system_source_id)
    target_system_name = get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}]"
  end

  def get_event_data(:map_connection_removed, %{
        "solar_system_source_id" => solar_system_source_id,
        "solar_system_target_id" => solar_system_target_id
      }) do
    source_system_name = get_system_name(solar_system_source_id)
    target_system_name = get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}]"
  end

  def get_event_data(:map_connection_updated, %{
        "key" => key,
        "solar_system_source_id" => solar_system_source_id,
        "solar_system_target_id" => solar_system_target_id,
        "value" => value
      }) do
    source_system_name = get_system_name(solar_system_source_id)
    target_system_name = get_system_name(solar_system_target_id)
    "[#{source_system_name}:#{target_system_name}] #{key} - #{inspect(value)}"
  end

  def get_event_data(:map_rally_added, %{
        "solar_system_id" => solar_system_id
      }),
      do: get_system_name(solar_system_id)

  def get_event_data(:map_rally_cancelled, %{
        "solar_system_id" => solar_system_id
      }),
      do: get_system_name(solar_system_id)

  def get_event_data(_name, data), do: Jason.encode!(data)

  defp get_system_name(solar_system_id) when is_binary(solar_system_id),
    do: get_system_name(String.to_integer(solar_system_id))

  defp get_system_name(solar_system_id) do
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
