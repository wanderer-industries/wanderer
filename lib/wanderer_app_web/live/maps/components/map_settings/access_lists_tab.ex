defmodule WandererAppWeb.Maps.MapSettings.AccessListsTab do
  use WandererAppWeb, :html

  @default_search_results_limit 10

  attr :access_lists, :list, required: true
  attr :selected_ids, :list, required: true
  attr :saved_ids, :list, required: true
  attr :marked_ids, :list, required: true
  attr :search, :string, required: true
  attr :search_focused, :boolean, required: true

  def content(assigns) do
    assigned_access_lists =
      Enum.filter(assigns.access_lists, &(&1.id in assigns.selected_ids))

    assigned_ids = Enum.map(assigned_access_lists, & &1.id)
    marked_count = Enum.count(assigned_ids, &(&1 in assigns.marked_ids))

    assigns =
      assign(assigns,
        assigned_access_lists: assigned_access_lists,
        search_results: search_results(assigns),
        assigned_ids: Enum.join(assigned_ids, ","),
        all_assigned_marked: assigned_ids != [] and marked_count == length(assigned_ids),
        some_assigned_marked: marked_count > 0 and marked_count < length(assigned_ids)
      )

    ~H"""
    <div class="flex h-full min-h-0 flex-col">
      <form
        phx-change="filter_access_lists"
        phx-click-away="blur_access_list_search"
        autocomplete="off"
        class="relative shrink-0"
      >
        <label for="access-list-search" class="mb-1 block text-sm text-neutral-300">
          Add an access list
        </label>
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-neutral-500"
          />
          <input
            id="access-list-search"
            type="text"
            inputmode="search"
            role="searchbox"
            name="access_list_search[query]"
            value={@search}
            placeholder="Search by access list or owner"
            phx-debounce="200"
            phx-focus="focus_access_list_search"
            class="p-inputtext p-component w-full py-2 pl-3 pr-9 text-sm placeholder:!text-neutral-600"
          />
        </div>
        <div
          :if={@search_focused}
          class="absolute z-20 mt-1 max-h-48 w-full overflow-y-auto border border-neutral-700 bg-neutral-900 shadow-lg"
        >
          <button
            :for={access_list <- @search_results}
            type="button"
            phx-click="add_access_list"
            phx-value-id={access_list.id}
            class="group grid w-full grid-cols-[max-content_minmax(0,1fr)_max-content] items-center gap-8 border-b border-neutral-700/80 px-3 py-2 text-left last:border-b-0 hover:bg-neutral-800"
          >
            <span class="truncate text-sm text-neutral-100">{access_list.name}</span>
            <span class="truncate text-sm text-neutral-400">{access_list.owner_name}</span>
            <span class="flex items-center gap-1 text-xs text-neutral-600 group-hover:text-neutral-500">
              <.icon name="hero-plus" class="size-3.5" /> Add
            </span>
          </button>
          <div :if={@search_results == []} class="px-3 py-4 text-center text-sm text-neutral-500">
            No access lists found
          </div>
        </div>
      </form>

      <div class="mt-5 flex min-h-0 flex-1 flex-col">
        <div class="flex items-center gap-3 border-b border-stone-700 pb-2">
          <span class="shrink-0 text-xs font-normal uppercase tracking-wide text-stone-500">
            Assigned access lists
          </span>
          <div class="flex-1" />
          <.button
            type="button"
            class="p-button-danger py-[3px]"
            disabled={@marked_ids == []}
            phx-click="delete_selected_access_lists"
          >
            <span class="flex items-center gap-1">
              <.icon name="hero-trash" class="size-3.5" /> Delete
            </span>
          </.button>
        </div>

        <div class="custom-scrollbar min-h-0 flex-1 overflow-y-auto pr-2">
          <table class="w-full border-collapse text-left">
            <colgroup>
              <col class="w-8" />
              <col class="w-px" />
              <col />
            </colgroup>
            <thead class="sticky top-0 z-10 bg-[var(--surface-card)]">
              <tr class="border-b border-neutral-700 text-xs uppercase tracking-wide text-neutral-500">
                <th class="h-8 px-1 font-normal">
                  <div class="flex h-8 items-center">
                    <.access_list_checkbox
                      id="map-access-lists-toggle-all"
                      event="toggle_all_access_lists"
                      checked={@all_assigned_marked}
                      partial={@some_assigned_marked}
                      disabled={@assigned_access_lists == []}
                      visible_ids={@assigned_ids}
                    />
                  </div>
                </th>
                <th class="h-8 whitespace-nowrap px-1 pr-8 font-normal">Access List</th>
                <th class="h-8 px-1 font-normal">Owner</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={access_list <- @assigned_access_lists}
                class={[
                  "border-b border-neutral-700/80 transition-colors",
                  classes(
                    "bg-emerald-950/30 hover:bg-emerald-950/45": access_list.id not in @saved_ids,
                    "hover:bg-neutral-800/60": access_list.id in @saved_ids
                  )
                ]}
              >
                <td class="h-8 px-1">
                  <div class="flex h-8 items-center">
                    <.access_list_checkbox
                      id={"map-access-list-#{access_list.id}"}
                      event="toggle_access_list_selection"
                      access_list_id={access_list.id}
                      checked={access_list.id in @marked_ids}
                    />
                  </div>
                </td>
                <td class="h-8 whitespace-nowrap px-1 pr-8 align-middle">
                  <label
                    for={"map-access-list-#{access_list.id}"}
                    class="block cursor-pointer truncate text-sm text-neutral-100"
                  >
                    {access_list.name}
                  </label>
                </td>
                <td class="h-8 truncate px-1 align-middle text-sm text-neutral-400">
                  {access_list.owner_name}
                </td>
              </tr>
              <tr :if={@assigned_access_lists == []}>
                <td colspan="3" class="h-28 text-center text-sm text-neutral-500">
                  No access lists assigned
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :access_list_id, :string, default: nil
  attr :visible_ids, :string, default: nil
  attr :checked, :boolean, required: true
  attr :partial, :boolean, default: false
  attr :disabled, :boolean, default: false

  defp access_list_checkbox(assigns) do
    ~H"""
    <div
      class={[
        "checkboxRoot sizeM p-checkbox p-component",
        classes("p-highlight": @checked or @partial, "p-disabled": @disabled)
      ]}
      data-p-highlight={@checked or @partial}
      data-p-disabled={@disabled}
      data-pc-name="checkbox"
      data-pc-section="root"
    >
      <input
        id={@id}
        type="checkbox"
        class="p-checkbox-input"
        checked={@checked}
        disabled={@disabled}
        aria-checked={checkbox_aria_state(@checked, @partial)}
        phx-click={@event}
        phx-value-id={@access_list_id}
        phx-value-ids={@visible_ids}
        data-pc-section="input"
      />
      <div
        class="p-checkbox-box"
        data-p-highlight={@checked or @partial}
        data-p-disabled={@disabled}
        data-pc-section="box"
      >
        <.icon :if={@checked} name="hero-check" class="p-icon p-checkbox-icon size-3.5" />
        <.icon
          :if={@partial and not @checked}
          name="hero-minus"
          class="p-icon p-checkbox-icon size-3.5"
        />
      </div>
    </div>
    """
  end

  defp search_results(%{
         access_lists: access_lists,
         selected_ids: selected_ids,
         search: search
       }) do
    normalized_search = search |> String.trim() |> String.downcase()

    if normalized_search == "" do
      access_lists
      |> Enum.reject(&(&1.id in selected_ids))
      |> Enum.take(@default_search_results_limit)
    else
      Enum.filter(access_lists, fn access_list ->
        matches_search =
          access_list.name |> String.downcase() |> String.contains?(normalized_search) or
            access_list.owner_name |> String.downcase() |> String.contains?(normalized_search)

        access_list.id not in selected_ids and matches_search
      end)
    end
  end

  defp checkbox_aria_state(_checked, true), do: "mixed"
  defp checkbox_aria_state(checked, false), do: to_string(checked)
end
