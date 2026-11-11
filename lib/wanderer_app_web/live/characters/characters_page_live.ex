defmodule WandererAppWeb.CharactersPageLive do
  @moduledoc false

  use WandererAppWeb, :live_view

  alias WandererAppWeb.{CharactersLive, PageCharactersLive}

  @impl true
  def mount(params, session, socket) do
    page_module = page_module()

    if socket.assigns.live_action == :authorize and page_module == PageCharactersLive do
      {:ok, redirect(socket, to: ~p"/characters")}
    else
      socket = assign(socket, :characters_page_module, page_module)
      page_module.mount(params, session, socket)
    end
  end

  @impl true
  def handle_params(params, url, socket) do
    delegate_optional(socket, :handle_params, [params, url, socket], {:noreply, socket})
  end

  @impl true
  def handle_event(event, params, socket) do
    page_module(socket).handle_event(event, params, socket)
  end

  @impl true
  def handle_info(message, socket) do
    page_module(socket).handle_info(message, socket)
  end

  @impl true
  def terminate(reason, socket) do
    delegate_optional(socket, :terminate, [reason, socket], :ok)
  end

  @impl true
  def render(assigns) do
    module = assigns.characters_page_module
    module.render(assigns)
  end

  defp delegate_optional(socket, function, arguments, fallback) do
    case socket.assigns[:characters_page_module] do
      module when is_atom(module) ->
        if function_exported?(module, function, length(arguments)) do
          apply(module, function, arguments)
        else
          fallback
        end

      nil ->
        fallback
    end
  end

  defp page_module do
    if WandererApp.Env.legacy_characters_page_enabled?() do
      CharactersLive
    else
      PageCharactersLive
    end
  end

  defp page_module(socket), do: socket.assigns.characters_page_module
end
