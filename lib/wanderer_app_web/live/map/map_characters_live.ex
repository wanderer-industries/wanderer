defmodule WandererAppWeb.MapCharactersLive do
  use WandererAppWeb, :live_view

  require Logger

  alias WandererAppWeb.MapCharacters

  @refresh_interval :timer.seconds(30)

  def mount(
        %{"slug" => map_slug} = _params,
        _session,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    WandererApp.Maps.check_user_can_delete_map(map_slug, current_user)
    |> case do
      {:ok,
       %{
         id: map_id,
         name: map_name
       } = _map} ->
        {:ok,
         socket
         |> assign(
           map_id: map_id,
           map_name: map_name,
           map_slug: map_slug,
           character_view: :active
         )
         |> assign(:groups, [])}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have an access.")
         |> push_navigate(to: ~p"/maps")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(user_id: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(
        :refresh_tracking_data,
        socket
      ) do
    Process.send_after(self(), :refresh_tracking_data, @refresh_interval)
    {:noreply, socket |> load_characters()}
  end

  @impl true
  def handle_info(
        _event,
        socket
      ) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_character_view", %{"view" => view}, socket)
      when view in ["active", "tracked"] do
    character_view = if view == "tracked", do: :tracked, else: :active
    {:noreply, socket |> assign(:character_view, character_view) |> load_characters()}
  end

  def handle_event("change_character_view", _params, socket), do: {:noreply, socket}

  def handle_event(
        "untrack",
        %{"event-data" => character_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: _current_user,
            character_settings: character_settings
          }
        } = socket
      ) do
    socket =
      character_settings
      |> Enum.find(&(&1.character_id == character_id))
      |> case do
        nil ->
          socket

        character_setting ->
          case character_setting.tracked do
            true ->
              case WandererApp.MapCharacterSettingsRepo.untrack(character_setting) do
                {:ok, _settings} ->
                  WandererApp.Map.Server.untrack_characters(
                    map_id,
                    [character_setting.character_id]
                  )

                  socket |> put_flash(:info, "Character untracked!") |> load_characters()

                {:error, reason} ->
                  Logger.error(
                    "Unable to untrack character #{character_id} for map #{map_id}: #{inspect(reason)}"
                  )

                  put_flash(socket, :error, "Unable to untrack character. Please try again.")
              end

            _ ->
              socket
          end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, body, socket) do
    Logger.warning(fn -> "unhandled event: #{event} #{inspect(body)}" end)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    Process.send_after(self(), :refresh_tracking_data, @refresh_interval)

    socket
    |> assign(:active_page, :map_characters)
    |> load_characters()
  end

  defp load_characters(%{assigns: %{map_id: map_id, character_view: view}} = socket) do
    view_label = if view == :tracked, do: "All tracked characters", else: "Active sessions"

    socket =
      socket
      |> assign(:character_view_label, view_label)
      |> assign(:page_title, "Map - #{view_label}")

    case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} ->
        {:ok, present_characters} =
          WandererApp.Cache.lookup("map_#{map_id}:presence_data", [])

        saved_flags = Map.new(settings, &{&1.character_id, &1.tracked == true})

        selected_characters = select_characters(view, settings, present_characters)
        characters_by_id = load_character_records(map_id, selected_characters)

        map_characters =
          Enum.flat_map(selected_characters, fn presence ->
            case Map.fetch(characters_by_id, presence.character_id) do
              {:ok, character} ->
                # Saved preferences take precedence over stale presence metadata after untracking.
                tracked = Map.get(saved_flags, presence.character_id, presence.tracked == true)

                [
                  character
                  |> Map.merge(%{from: Map.get(presence, :from), tracked: tracked})
                  |> map_ui_character()
                ]

              _ ->
                Logger.warning(
                  "Unable to load character #{presence.character_id} for map #{map_id}"
                )

                []
            end
          end)

        groups =
          map_characters
          |> Enum.group_by(& &1.user_id)
          |> Enum.map(fn {user_id, characters} -> %{id: user_id, characters: characters} end)

        assign(socket,
          character_settings: settings,
          characters_count: length(map_characters),
          groups: groups,
          characters_load_error: false,
          characters_incomplete: length(map_characters) < length(selected_characters)
        )

      {:error, reason} ->
        Logger.error("Unable to load character settings for map #{map_id}: #{inspect(reason)}")

        assign(socket,
          character_settings: [],
          characters_count: 0,
          groups: [],
          characters_load_error: true,
          characters_incomplete: false
        )
    end
  end

  # Batched equivalent of Character.get_character/1; keep cache-only runtime updates intact.
  defp load_character_records(_map_id, []), do: %{}

  defp load_character_records(map_id, selected_characters) do
    character_ids = selected_characters |> Enum.map(& &1.character_id) |> Enum.uniq()

    {cached_characters, missing_ids} =
      Enum.reduce(character_ids, {%{}, []}, fn character_id, {cached, missing} ->
        case Cachex.get(:character_cache, character_id) do
          {:ok, character} when not is_nil(character) ->
            {Map.put(cached, character_id, character), missing}

          _ ->
            {cached, [character_id | missing]}
        end
      end)

    case missing_ids do
      [] ->
        cached_characters

      _ ->
        case WandererApp.Api.Character.read(query: [filter: [id: [in: missing_ids]]]) do
          {:ok, characters} ->
            Enum.reduce(characters, cached_characters, fn character, loaded ->
              Cachex.put(:character_cache, character.id, character)
              Map.put(loaded, character.id, character)
            end)

          {:error, reason} ->
            Logger.error("Unable to load character records for map #{map_id}: #{inspect(reason)}")
            cached_characters
        end
    end
  end

  defp select_characters(:active, _settings, present_characters), do: present_characters

  defp select_characters(:tracked, settings, present_characters) do
    presence_by_id = Map.new(present_characters, &{&1.character_id, &1})

    settings
    |> Enum.filter(&(&1.tracked == true))
    |> Enum.map(fn setting ->
      %{
        character_id: setting.character_id,
        tracked: true,
        from: presence_by_id |> Map.get(setting.character_id, %{}) |> Map.get(:from)
      }
    end)
  end

  defp map_ui_character(character) do
    character
    |> Map.take([
      :id,
      :user_id,
      :eve_id,
      :name,
      :online,
      :corporation_id,
      :corporation_name,
      :corporation_ticker,
      :alliance_id,
      :alliance_name,
      :alliance_ticker,
      :from,
      :tracked
    ])
  end
end
