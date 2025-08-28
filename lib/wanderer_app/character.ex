defmodule WandererApp.Character do
  @moduledoc false
  use Nebulex.Caching

  require Logger

  @read_character_wallet_scope "esi-wallet.read_character_wallet.v1"
  @read_corp_wallet_scope "esi-wallet.read_corporation_wallets.v1"

  @default_character_tracking_data %{
    solar_system_id: nil,
    structure_id: nil,
    station_id: nil,
    ship: nil,
    ship_name: nil,
    ship_item_id: nil
  }

  def get_by_eve_id(character_eve_id) when is_binary(character_eve_id) do
    WandererApp.Api.Character.by_eve_id(character_eve_id)
  end

  def get_character(character_id) when not is_nil(character_id) do
    case Cachex.get(:character_cache, character_id) do
      {:ok, nil} ->
        case WandererApp.Api.Character.by_id(character_id) do
          {:ok, character} ->
            Cachex.put(:character_cache, character_id, character)
            {:ok, character}

          error ->
            {:error, :not_found}
        end

      {:ok, character} ->
        {:ok, character}
    end
  end

  def get_character(_character_id), do: {:ok, nil}

  def get_character!(character_id) do
    case get_character(character_id) do
      {:ok, character} ->
        character

      _ ->
        Logger.error("Failed to get character #{character_id}")
        nil
    end
  end

  def get_map_character(map_id, character_id, opts \\ []) do
    case get_character(character_id) do
      {:ok, character} ->
        # If we are forcing the character to not be present, we merge the character state with map settings
        character_is_present =
          if opts |> Keyword.get(:not_present, false) do
            false
          else
            WandererApp.Character.TrackerManager.Impl.character_is_present(map_id, character_id)
          end

        {:ok,
         character
         |> maybe_merge_map_character_settings(
           map_id,
           character_is_present
         )}

      error ->
        error
    end
  end

  def get_map_character!(map_id, character_id) do
    case get_map_character(map_id, character_id) do
      {:ok, character} ->
        character

      _ ->
        Logger.error("Failed to get map character #{map_id} #{character_id}")
        nil
    end
  end

  def get_character_eve_ids!(character_ids),
    do:
      character_ids
      |> Enum.map(fn character_id ->
        character_id |> get_character!() |> Map.get(:eve_id)
      end)

  def update_character(character_id, character_update) do
    Cachex.get_and_update(:character_cache, character_id, fn character ->
      case character do
        nil ->
          case WandererApp.Api.Character.by_id(character_id) do
            {:ok, character} ->
              {:commit, Map.merge(character, character_update)}

            _ ->
              {:ignore, nil}
          end

        _ ->
          {:commit, Map.merge(character, character_update)}
      end
    end)
  end

  def get_character_state(character_id, init_if_empty? \\ true) do
    case Cachex.get(:character_state_cache, character_id) do
      {:ok, nil} ->
        case init_if_empty? do
          true ->
            character_state = WandererApp.Character.Tracker.init(character_id: character_id)
            Cachex.put(:character_state_cache, character_id, character_state)
            {:ok, character_state}

          _ ->
            {:ok, nil}
        end

      {:ok, character_state} ->
        {:ok, character_state}
    end
  end

  def get_character_state!(character_id) do
    case get_character_state(character_id) do
      {:ok, character_state} ->
        character_state

      _ ->
        Logger.error("Failed to get character_state #{character_id}")
        throw("Failed to get character_state #{character_id}")
    end
  end

  def update_character_state(character_id, character_state_update) do
    Cachex.get_and_update(:character_state_cache, character_id, fn character_state ->
      case character_state do
        nil ->
          new_state = WandererApp.Character.Tracker.init(character_id: character_id)
          :telemetry.execute([:wanderer_app, :character, :tracker, :started], %{count: 1})

          {:commit, Map.merge(new_state, character_state_update)}

        _ ->
          {:commit, Map.merge(character_state, character_state_update)}
      end
    end)
  end

  def delete_character_state(character_id) do
    Cachex.del(:character_state_cache, character_id)
  end

  def set_autopilot_waypoint(
        character_id,
        destination_id,
        opts
      ) do
    {:ok, %{access_token: access_token}} = WandererApp.Character.get_character(character_id)

    WandererApp.Esi.set_autopilot_waypoint(
      opts[:add_to_beginning],
      opts[:clear_other_waypoints],
      destination_id,
      access_token: access_token
    )

    :ok
  end

  def search(character_id, opts \\ []) do
    get_character(character_id)
    |> case do
      {:ok, %{access_token: access_token, eve_id: eve_id} = _character} ->
        case WandererApp.Esi.search(eve_id |> String.to_integer(),
               access_token: access_token,
               character_id: character_id,
               refresh_token?: true,
               params: opts[:params]
             ) do
          {:ok, result} ->
            {:ok, result |> prepare_search_results()}

          error ->
            Logger.warning("#{__MODULE__} failed search: #{inspect(error)}")
            {:ok, []}
        end

      error ->
        {:ok, []}
    end
  end

  def can_track_wallet?(%{scopes: scopes, id: character_id} = _character)
      when is_binary(scopes) and is_binary(character_id),
      do: scopes |> String.split(" ") |> Enum.member?(@read_character_wallet_scope)

  def can_track_wallet?(_), do: false

  def can_track_corp_wallet?(%{scopes: scopes} = _character)
      when not is_nil(scopes),
      do: scopes |> String.split(" ") |> Enum.member?(@read_corp_wallet_scope)

  def can_track_corp_wallet?(_), do: false

  def can_pause_tracking?(character_id) do
    case get_character(character_id) do
      {:ok, %{tracking_pool: tracking_pool} = character} when not is_nil(character) ->
        not WandererApp.Env.character_tracking_pause_disabled?() &&
          not can_track_wallet?(character) &&
          (is_nil(tracking_pool) || tracking_pool == "default")

      _ ->
        true
    end
  end

  def get_ship(%{ship: ship_type_id, ship_name: ship_name} = _character)
      when not is_nil(ship_type_id) and is_integer(ship_type_id) do
    ship_type_id
    |> WandererApp.CachedInfo.get_ship_type()
    |> case do
      {:ok, ship_type_info} when not is_nil(ship_type_info) ->
        %{ship_type_id: ship_type_id, ship_name: ship_name, ship_type_info: ship_type_info}

      _ ->
        %{ship_type_id: ship_type_id, ship_name: ship_name, ship_type_info: %{}}
    end
  end

  def get_ship(%{ship_name: ship_name} = _character) when is_binary(ship_name),
    do: %{ship_name: ship_name, ship_type_info: %{}}

  def get_ship(_),
    do: %{ship_name: nil, ship_type_info: %{}}

  def get_location(
        %{solar_system_id: solar_system_id, structure_id: structure_id, station_id: station_id} =
          _character
      ) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, system_static_info} when not is_nil(system_static_info) ->
        %{
          solar_system_id: solar_system_id,
          structure_id: structure_id,
          station_id: station_id,
          solar_system_info: system_static_info
        }

      _ ->
        %{
          solar_system_id: solar_system_id,
          structure_id: structure_id,
          station_id: station_id,
          solar_system_info: %{}
        }
    end
  end

  defp maybe_merge_map_character_settings(%{id: character_id} = character, _map_id, true) do
    {:ok, tracking_paused} =
      WandererApp.Cache.lookup("character:#{character_id}:tracking_paused", false)

    character
    |> Map.merge(%{tracking_paused: tracking_paused})
  end

  defp maybe_merge_map_character_settings(
         %{id: character_id} = character,
         map_id,
         _character_is_present
       ) do
    {:ok, tracking_paused} =
      WandererApp.Cache.lookup("character:#{character_id}:tracking_paused", false)

    WandererApp.MapCharacterSettingsRepo.get(map_id, character_id)
    |> case do
      {:ok, settings} when not is_nil(settings) ->
        character
        |> Map.merge(%{
          solar_system_id: settings.solar_system_id,
          structure_id: settings.structure_id,
          station_id: settings.station_id,
          ship: settings.ship,
          ship_name: settings.ship_name,
          ship_item_id: settings.ship_item_id
        })

      _ ->
        character
        |> Map.merge(@default_character_tracking_data)
    end
    |> Map.merge(%{online: false, tracking_paused: tracking_paused})
  end

  defp prepare_search_results(result) do
    {:ok, characters} =
      load_eve_info(Map.get(result, "character"), :get_character_info, &map_character_info/1)

    {:ok, corporations} =
      load_eve_info(
        Map.get(result, "corporation"),
        :get_corporation_info,
        &map_corporation_info/1
      )

    {:ok, alliances} =
      load_eve_info(Map.get(result, "alliance"), :get_alliance_info, &map_alliance_info/1)

    [[characters | corporations] | alliances] |> List.flatten()
  end

  defp load_eve_info(nil, _, _), do: {:ok, []}

  defp load_eve_info([], _, _), do: {:ok, []}

  defp load_eve_info(eve_ids, method, map_function),
    do:
      {:ok,
       Enum.map(eve_ids, fn eve_id ->
         Task.async(fn -> apply(WandererApp.Esi.ApiClient, method, [eve_id]) end)
       end)
       # 145000 == Timeout in milliseconds
       |> Enum.map(fn task -> Task.await(task, 145_000) end)
       |> Enum.map(fn result ->
         case result do
           {:ok, result} -> map_function.(result)
           _ -> nil
         end
       end)
       |> Enum.filter(fn result -> not is_nil(result) end)}

  defp map_alliance_info(info) do
    %{
      label: info["name"],
      value: info["eve_id"] |> to_string(),
      alliance: true
    }
  end

  defp map_character_info(info) do
    %{
      label: info["name"],
      value: info["eve_id"] |> to_string(),
      character: true
    }
  end

  defp map_corporation_info(info) do
    %{
      label: info["name"],
      value: info["eve_id"] |> to_string(),
      corporation: true
    }
  end

  @doc """
  Finds a character by EVE ID from a user's active characters.

  ## Parameters
  - `current_user_id`: The current user ID
  - `character_eve_id`: The EVE ID of the character to find

  ## Returns
  - `{:ok, character}` if the character is found
  - `{:error, :character_not_found}` if the character is not found
  """
  def find_character_by_eve_id(current_user_id, character_eve_id) do
    {:ok, all_user_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: current_user_id})

    case Enum.find(all_user_characters, fn char ->
           "#{char.eve_id}" == "#{character_eve_id}"
         end) do
      nil ->
        {:error, :character_not_found}

      character ->
        {:ok, character}
    end
  end

  @doc """
  Finds a character by character ID from a user's characters.

  ## Parameters
  - `current_user`: The current user struct
  - `char_id`: The character ID to find

  ## Returns
  - `{:ok, character}` if the character is found
  - `{:error, :character_not_found}` if the character is not found
  """
  def find_user_character(current_user, char_id) do
    case Enum.find(current_user.characters, &("#{&1.id}" == "#{char_id}")) do
      nil ->
        {:error, :character_not_found}

      char ->
        {:ok, char}
    end
  end
end
