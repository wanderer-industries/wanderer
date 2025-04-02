defmodule WandererApp.Character do
  @moduledoc false
  use Nebulex.Caching

  require Logger

  @read_character_wallet_scope "esi-wallet.read_character_wallet.v1"
  @read_corp_wallet_scope "esi-wallet.read_corporation_wallets.v1"

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "characters-#{character_eve_id}"
            )
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

          _ ->
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
    {:ok, %{access_token: access_token, eve_id: eve_id} = _character} =
      get_character(character_id)

    case WandererApp.Esi.search(eve_id |> String.to_integer(),
           access_token: access_token,
           character_id: character_id,
           refresh_token?: true,
           params: opts[:params]
         ) do
      {:ok, result} ->
        {:ok, result |> _prepare_search_results()}

      {:error, error} ->
        Logger.warning("#{__MODULE__} failed search: #{inspect(error)}")
        {:ok, []}
    end
  end

  def can_track_wallet?(%{scopes: scopes} = _character) when not is_nil(scopes) do
    scopes |> String.split(" ") |> Enum.member?(@read_character_wallet_scope)
  end

  def can_track_wallet?(_), do: false

  def can_track_corp_wallet?(%{scopes: scopes} = _character) when not is_nil(scopes) do
    scopes |> String.split(" ") |> Enum.member?(@read_corp_wallet_scope)
  end

  def can_track_corp_wallet?(_), do: false

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

  defp _prepare_search_results(result) do
    {:ok, characters} =
      _load_eve_info(Map.get(result, "character"), :get_character_info, &_map_character_info/1)

    {:ok, corporations} =
      _load_eve_info(
        Map.get(result, "corporation"),
        :get_corporation_info,
        &_map_corporation_info/1
      )

    {:ok, alliances} =
      _load_eve_info(Map.get(result, "alliance"), :get_alliance_info, &_map_alliance_info/1)

    [[characters | corporations] | alliances] |> List.flatten()
  end

  defp _load_eve_info(nil, _, _), do: {:ok, []}

  defp _load_eve_info([], _, _), do: {:ok, []}

  defp _load_eve_info(eve_ids, method, map_function),
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

  defp _map_alliance_info(info) do
    %{
      label: info["name"],
      value: info["eve_id"] |> to_string(),
      alliance: true
    }
  end

  defp _map_character_info(info) do
    %{
      label: info["name"],
      value: info["eve_id"] |> to_string(),
      character: true
    }
  end

  defp _map_corporation_info(info) do
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
