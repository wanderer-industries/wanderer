defmodule WandererAppWeb.AdminCharactersLive do
  @moduledoc """
  Admin LiveView for viewing all registered characters on the server.
  """
  use WandererAppWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  @characters_per_page 50

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket)
      when not is_nil(user_id) and is_connected?(socket) do
    {:ok,
     socket
     |> assign(
       characters: AsyncResult.loading(),
       search_term: "",
       show_deleted: true,
       page: 1,
       per_page: @characters_per_page,
       sort_by: :name,
       sort_dir: :asc
     )
     |> load_characters_async()}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       characters: AsyncResult.loading(),
       search_term: "",
       show_deleted: true,
       page: 1,
       per_page: @characters_per_page,
       sort_by: :name,
       sort_dir: :asc
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
    |> assign(:page_title, "Admin - Characters")
  end

  defp load_characters_async(socket) do
    socket
    |> assign_async(:characters, fn -> load_all_characters() end)
  end

  defp load_all_characters do
    case WandererApp.Api.Character.admin_all() do
      {:ok, characters} ->
        {:ok, %{characters: characters}}

      _ ->
        {:ok, %{characters: []}}
    end
  end

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
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {sort_by, sort_dir} =
      if socket.assigns.sort_by == field do
        {field, toggle_dir(socket.assigns.sort_dir)}
      else
        {field, :asc}
      end

    {:noreply, socket |> assign(sort_by: sort_by, sort_dir: sort_dir, page: 1)}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, socket |> assign(:page, String.to_integer(page))}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  def filter_characters(characters, search_term, show_deleted) do
    characters
    |> Enum.filter(fn char ->
      (show_deleted or not char.deleted) and
        (search_term == "" or
           String.contains?(String.downcase(char.name || ""), String.downcase(search_term)) or
           String.contains?(
             String.downcase(char.corporation_name || ""),
             String.downcase(search_term)
           ) or
           String.contains?(
             String.downcase(char.alliance_name || ""),
             String.downcase(search_term)
           ))
    end)
  end

  def sort_characters(characters, sort_by, sort_dir) do
    Enum.sort_by(characters, &sort_value(&1, sort_by), sort_dir)
  end

  defp sort_value(char, :name), do: String.downcase(char.name || "")
  defp sort_value(char, :corporation), do: String.downcase(char.corporation_name || "")
  defp sort_value(char, :alliance), do: String.downcase(char.alliance_name || "")
  defp sort_value(char, :user), do: String.downcase(user_name(char.user))
  defp sort_value(char, :registered), do: char.inserted_at || ~U[1970-01-01 00:00:00Z]

  defp toggle_dir(:asc), do: :desc
  defp toggle_dir(:desc), do: :asc

  def paginate(items, page, per_page) do
    items
    |> Enum.drop((page - 1) * per_page)
    |> Enum.take(per_page)
  end

  def total_pages(items, per_page) do
    max(1, ceil(length(items) / per_page))
  end

  def format_date(nil), do: "-"

  def format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def user_name(nil), do: "Unlinked"
  def user_name(%{name: name}), do: name
end
