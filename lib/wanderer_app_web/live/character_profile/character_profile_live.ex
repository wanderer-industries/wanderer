defmodule WandererAppWeb.CharacterProfileLive do
  use WandererAppWeb, :live_view

  require Logger

  @impl true
  def mount(%{"eve_id" => eve_id_str}, _session, socket) do
    case Integer.parse(eve_id_str) do
      {eve_id, ""} ->
        case load_character(eve_id) do
          {:ok, character} ->
            is_owner = owner?(socket.assigns.current_user, eve_id_str)
            description_html = render_description(character.description)

            {:ok,
             assign(socket,
               page_title: character.name,
               profile: build_profile(character),
               is_owner: is_owner,
               editing: false,
               description_html: description_html,
               description_raw: character.description || ""
             )}

          {:error, _} ->
            {:ok,
             socket
             |> put_flash(:error, "Character not found")
             |> redirect(to: "/")}
        end

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid character ID")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    if socket.assigns.is_owner do
      {:noreply, assign(socket, editing: !socket.assigns.editing)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_description", _params, socket) do
    if socket.assigns.is_owner do
      {:noreply, push_event(socket, "request_editor_content", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  def handle_event("content-text-change", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("editor_content_markdown", %{"markdown" => markdown}, socket) do
    if socket.assigns.is_owner do
      markdown = String.slice(markdown, 0, 10_000)
      eve_id_str = socket.assigns.profile.eve_id

      case WandererApp.Api.Character.by_eve_id(eve_id_str) do
        {:ok, character} ->
          case WandererApp.Api.Character.update_description(character, %{description: markdown}) do
            {:ok, _updated} ->
              Cachex.del(:api_cache, "character_profile_#{eve_id_str}")
              description_html = render_description(markdown)

              {:noreply,
               socket
               |> assign(
                 editing: false,
                 description_html: description_html,
                 description_raw: markdown
               )
               |> put_flash(:info, "Description updated")}

            {:error, reason} ->
              Logger.error("Failed to update description: #{inspect(reason)}")
              {:noreply, put_flash(socket, :error, "Failed to save description")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Character not found")}
      end
    else
      {:noreply, socket}
    end
  end

  defp owner?(current_user, eve_id_str) do
    case current_user do
      %{characters: characters} when is_list(characters) ->
        Enum.any?(characters, fn c -> to_string(c.eve_id) == eve_id_str end)

      _ ->
        false
    end
  end

  defp load_character(eve_id) do
    WandererApp.Api.Character.by_eve_id(eve_id)
  end

  defp build_profile(character) do
    %{
      eve_id: character.eve_id,
      name: character.name,
      corporation_id: character.corporation_id,
      corporation_name: character.corporation_name,
      corporation_ticker: character.corporation_ticker,
      alliance_id: character.alliance_id,
      alliance_name: character.alliance_name,
      alliance_ticker: character.alliance_ticker,
      online: character.online
    }
  end

  defp render_description(nil), do: ""
  defp render_description(""), do: ""

  defp render_description(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} ->
        HtmlSanitizeEx.markdown_html(html)

      {:error, _, _} ->
        ""
    end
  end
end
