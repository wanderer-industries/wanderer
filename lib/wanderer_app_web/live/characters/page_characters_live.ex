defmodule WandererAppWeb.PageCharactersLive do
  @moduledoc """
  Socket host for the React Characters page prototype.

  The existing `CharactersLive` remains the production implementation while
  this module exposes an isolated event contract for the React page.
  """

  use WandererAppWeb, :live_view

  @page_event "page_characters_event"
  @snapshot_command "snapshot"
  @character_updated_command "character_updated"

  @impl true
  def mount(_params, %{"user_id" => user_id}, socket) when not is_nil(user_id) do
    if connected?(socket) do
      user_id
      |> fetch_characters!()
      |> subscribe_to_character_updates()
    end

    {:ok,
     assign(socket,
       active_page: :characters_react,
       page_title: "Characters",
       user_id: user_id
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :characters_react,
       page_title: "Characters",
       user_id: nil
     )}
  end

  @impl true
  def handle_event("page_characters_init", _params, socket) do
    {:noreply, push_snapshot(socket)}
  end

  @impl true
  def handle_event("page_characters_authorize", params, socket) do
    track_wallet = Map.get(params, "track_wallet", false)
    active_pool = WandererApp.Character.TrackingConfigUtils.get_active_pool!()

    {:ok, esi_config} = Cachex.get(:esi_auth_cache, "config_#{active_pool}")
    WandererApp.Cache.put("invite_#{esi_config.uuid}", true, ttl: :timer.minutes(30))

    {:reply, %{ok: true}, push_navigate(socket, to: auth_path(esi_config.uuid, track_wallet))}
  end

  @impl true
  def handle_event(
        "page_characters_delete",
        %{"character_id" => character_id},
        %{assigns: %{user_id: user_id}} = socket
      ) do
    case delete_character(character_id, user_id) do
      :ok ->
        snapshot = build_snapshot(user_id)

        {:reply, %{ok: true, snapshot: snapshot}, push_snapshot_event(socket, snapshot)}

      {:error, :not_found} ->
        {:reply, %{ok: false, error: "Character not found."}, socket}

      {:error, reason} ->
        {:reply, %{ok: false, error: "Unable to delete character: #{inspect(reason)}"}, socket}
    end
  end

  @impl true
  def handle_info({:character_alliance, _update}, socket), do: refresh(socket)

  @impl true
  def handle_info({:character_corporation, _update}, socket), do: refresh(socket)

  @impl true
  def handle_info({:character_wallet_balance, _character_id}, socket), do: refresh(socket)

  @impl true
  def handle_info({:character_tracking_updated, character_id}, socket) do
    push_character_update(socket, character_id)
  end

  @impl true
  def handle_info(event, socket) when event in [:character_token_invalid, :token_updated],
    do: refresh(socket)

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, _socket) do
    WandererApp.Character.TrackerManager.unregister_consumer({:characters_page, self()})
    :ok
  end

  defp refresh(%{assigns: %{user_id: nil}} = socket), do: {:noreply, socket}
  defp refresh(socket), do: {:noreply, push_snapshot(socket)}

  defp push_snapshot(%{assigns: %{user_id: nil}} = socket) do
    push_snapshot_event(socket, empty_snapshot())
  end

  defp push_snapshot(%{assigns: %{user_id: user_id}} = socket) do
    push_snapshot_event(socket, build_snapshot(user_id))
  end

  defp push_snapshot_event(socket, snapshot) do
    push_event(socket, @page_event, %{type: @snapshot_command, body: snapshot})
  end

  defp push_character_update(%{assigns: %{user_id: user_id}} = socket, character_id)
       when not is_nil(user_id) do
    case WandererAppWeb.HandlerAuth.authorize_character(character_id, user_id) do
      {:ok, character} ->
        {:noreply,
         push_event(socket, @page_event, %{
           type: @character_updated_command,
           body: serialize_character(character)
         })}

      _error ->
        {:noreply, socket}
    end
  end

  defp push_character_update(socket, _character_id), do: {:noreply, socket}

  defp build_snapshot(user_id) do
    %{
      characters: user_id |> fetch_characters!() |> Enum.map(&serialize_character/1),
      wallet_tracking_enabled: WandererApp.Env.wallet_tracking_enabled?()
    }
  end

  defp empty_snapshot do
    %{characters: [], wallet_tracking_enabled: WandererApp.Env.wallet_tracking_enabled?()}
  end

  defp fetch_characters!(user_id) do
    {:ok, characters} = WandererApp.Api.Character.active_by_user(%{user_id: user_id})
    Enum.sort_by(characters, & &1.name, :asc)
  end

  defp subscribe_to_character_updates(characters) do
    Enum.each(characters, fn character ->
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{character.id}:alliance")
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{character.id}:corporation")
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{character.id}")
    end)

    character_ids = Enum.map(characters, & &1.id)

    :ok =
      WandererApp.Character.TrackerManager.register_consumer(
        character_ids,
        {:characters_page, self()},
        :slow,
        self()
      )
  end

  defp delete_character(character_id, user_id) do
    case WandererAppWeb.HandlerAuth.authorize_character(character_id, user_id) do
      {:ok, character} ->
        WandererApp.Character.TrackerManager.stop_tracking(character_id)

        with {:ok, settings} <-
               WandererApp.Api.MapCharacterSettings.tracked_by_character(%{
                 character_id: character_id
               }),
             :ok <- untrack_from_maps(settings),
             {:ok, _character} <- WandererApp.Api.Character.mark_as_deleted(character),
             {:ok, _character} <-
               WandererApp.Character.update_character(character_id, %{deleted: true, user_id: nil}) do
          :ok
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp untrack_from_maps(settings) do
    Enum.reduce_while(settings, :ok, fn item, :ok ->
      case WandererApp.MapCharacterSettingsRepo.untrack(item) do
        {:ok, _settings} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp serialize_character(character) do
    can_track_wallet? = WandererApp.Character.can_track_wallet?(character)
    ship = WandererApp.Character.get_ship(character)
    location = WandererApp.Character.get_location(character)

    %{
      id: character.id,
      eve_id: character.eve_id,
      name: character.name,
      corporation_id: character.corporation_id,
      corporation_name: character.corporation_name,
      corporation_ticker: character.corporation_ticker,
      alliance_id: character.alliance_id,
      alliance_name: character.alliance_name,
      alliance_ticker: character.alliance_ticker,
      location_name: nested_value(location, :solar_system_info, :solar_system_name),
      station_id: map_value(location, :station_id),
      station_name: station_name(location),
      structure_id: map_value(location, :structure_id),
      system_info: serialize_system_info(location),
      ship_name: nested_value(ship, :ship_type_info, :name) || map_value(ship, :ship_name),
      ship_type_id: map_value(ship, :ship_type_id),
      wallet_balance: wallet_balance(character, can_track_wallet?),
      show_wallet_balance: can_track_wallet?,
      online: character_online?(character),
      invalid_token: is_nil(character.access_token)
    }
  end

  defp character_online?(character) do
    case WandererApp.Character.get_character_state(character.id, false) do
      {:ok, %{is_online: is_online}} when is_boolean(is_online) -> is_online
      _state -> character.online == true
    end
  end

  defp wallet_balance(_character, false), do: 0.0

  defp wallet_balance(character, true) do
    case Ash.load(character, [:eve_wallet_balance]) do
      {:ok, %{eve_wallet_balance: balance}} -> normalize_number(balance)
      _error -> 0.0
    end
  end

  defp normalize_number(%Decimal{} = value), do: Decimal.to_float(value)
  defp normalize_number(value) when is_number(value), do: value
  defp normalize_number(_value), do: 0.0

  defp nested_value(map, parent_key, child_key) when is_map(map) do
    map |> Map.get(parent_key, %{}) |> map_value(child_key)
  end

  defp nested_value(_value, _parent_key, _child_key), do: nil

  defp map_value(map, key) when is_map(map), do: Map.get(map, key)
  defp map_value(_value, _key), do: nil

  defp serialize_system_info(location) do
    case map_value(location, :solar_system_info) do
      system_info when is_map(system_info) and map_size(system_info) > 0 ->
        Map.take(system_info, [
          :solar_system_id,
          :solar_system_name,
          :region_name,
          :system_class,
          :security,
          :class_title
        ])

      _value ->
        nil
    end
  end

  defp station_name(location) do
    case map_value(location, :station_id) do
      station_id when is_integer(station_id) ->
        case WandererApp.Esi.get_station_info(station_id) do
          {:ok, station} when is_map(station) ->
            Map.get(station, "name") || Map.get(station, :name)

          _error ->
            nil
        end

      _value ->
        nil
    end
  end

  defp auth_path(uuid, track_wallet), do: "/auth/eve?invite=#{uuid}&w=#{track_wallet}"
end
