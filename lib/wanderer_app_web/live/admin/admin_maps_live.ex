defmodule WandererAppWeb.AdminMapsLive do
  @moduledoc """
  Admin LiveView for managing all maps on the server.
  Allows admins to view, edit, soft-delete, and restore maps regardless of ownership.
  """
  use WandererAppWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  require Logger

  @maps_per_page 20

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket)
      when not is_nil(user_id) and is_connected?(socket) do
    {:ok,
     socket
     |> assign(
       maps: AsyncResult.loading(),
       search_term: "",
       show_deleted: true,
       page: 1,
       per_page: @maps_per_page
     )
     |> load_maps_async()}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       maps: AsyncResult.loading(),
       search_term: "",
       show_deleted: true,
       page: 1,
       per_page: @maps_per_page
     )}
  end

  @impl true
  def handle_params(params, _url, socket) when is_connected?(socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :admin)
    |> assign(:page_title, "Admin - Maps")
    |> assign(:selected_map, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => map_id}) do
    case load_map_for_edit(map_id) do
      {:ok, map} ->
        socket
        |> assign(:active_page, :admin)
        |> assign(:page_title, "Admin - Edit Map")
        |> assign(:selected_map, map)
        |> assign(
          :form,
          map
          |> AshPhoenix.Form.for_update(:update, forms: [auto?: true])
          |> to_form()
        )
        |> load_owner_options()

      {:error, _} ->
        socket
        |> put_flash(:error, "Map not found")
        |> push_navigate(to: ~p"/admin/maps")
    end
  end

  defp apply_action(socket, :view_acls, %{"id" => map_id}) do
    case load_map_with_acls(map_id) do
      {:ok, map} ->
        socket
        |> assign(:active_page, :admin)
        |> assign(:page_title, "Admin - Map ACLs")
        |> assign(:selected_map, map)

      {:error, _} ->
        socket
        |> put_flash(:error, "Map not found")
        |> push_navigate(to: ~p"/admin/maps")
    end
  end

  # Data loading functions
  defp load_maps_async(socket) do
    socket
    |> assign_async(:maps, fn -> load_all_maps() end)
  end

  defp load_all_maps do
    case WandererApp.Api.Map.admin_all() do
      {:ok, maps} ->
        maps =
          maps
          |> Enum.sort_by(& &1.name, :asc)

        {:ok, %{maps: maps}}

      _ ->
        {:ok, %{maps: []}}
    end
  end

  defp load_map_for_edit(map_id) do
    case WandererApp.Api.Map.by_id(map_id) do
      {:ok, map} ->
        {:ok, map} = Ash.load(map, [:owner, :acls])
        {:ok, map}

      error ->
        error
    end
  end

  defp load_map_with_acls(map_id) do
    case WandererApp.Api.Map.by_id(map_id) do
      {:ok, map} ->
        {:ok, map} = Ash.load(map, acls: [:owner, :members])
        {:ok, map}

      error ->
        error
    end
  end

  defp load_owner_options(socket) do
    case WandererApp.Api.Character.read() do
      {:ok, characters} ->
        options =
          characters
          |> Enum.map(fn c -> {c.name, c.id} end)
          |> Enum.sort_by(&elem(&1, 0))

        socket |> assign(:owner_options, options)

      _ ->
        socket |> assign(:owner_options, [])
    end
  end

  # Event handlers
  @impl true
  def handle_event("search", %{"value" => term}, socket) do
    {:noreply, socket |> assign(:search_term, term) |> assign(:page, 1)}
  end

  @impl true
  def handle_event("toggle_deleted", _params, socket) do
    {:noreply,
     socket |> assign(:show_deleted, not socket.assigns.show_deleted) |> assign(:page, 1)}
  end

  @impl true
  def handle_event("delete_map", %{"id" => map_id}, socket) do
    case soft_delete_map(map_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Map marked as deleted")
         |> load_maps_async()}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete map")}
    end
  end

  @impl true
  def handle_event("restore_map", %{"id" => map_id}, socket) do
    case restore_map(map_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Map restored successfully")
         |> load_maps_async()}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Failed to restore map")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _map} ->
        {:noreply,
         socket
         |> put_flash(:info, "Map updated successfully")
         |> push_navigate(to: ~p"/admin/maps")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, socket |> assign(:page, String.to_integer(page))}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp soft_delete_map(map_id) do
    case WandererApp.Api.Map.by_id(map_id) do
      {:ok, map} ->
        WandererApp.Api.Map.mark_as_deleted(map)

      error ->
        error
    end
  end

  defp restore_map(map_id) do
    case WandererApp.Api.Map.by_id(map_id) do
      {:ok, map} ->
        WandererApp.Api.Map.restore(map)

      error ->
        error
    end
  end

  def filter_maps(maps, search_term, show_deleted) do
    maps
    |> Enum.filter(fn map ->
      (show_deleted or not map.deleted) and
        (search_term == "" or
           String.contains?(String.downcase(map.name || ""), String.downcase(search_term)) or
           String.contains?(String.downcase(map.slug || ""), String.downcase(search_term)))
    end)
  end

  def paginate(maps, page, per_page) do
    maps
    |> Enum.drop((page - 1) * per_page)
    |> Enum.take(per_page)
  end

  def total_pages(maps, per_page) do
    max(1, ceil(length(maps) / per_page))
  end

  def format_date(nil), do: "-"

  def format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def owner_name(nil), do: "No owner"
  def owner_name(%{name: name}), do: name
end
