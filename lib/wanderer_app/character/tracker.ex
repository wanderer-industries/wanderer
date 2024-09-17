defmodule WandererApp.Character.Tracker do
  @moduledoc false
  require Logger

  alias WandererApp.Api.Character

  defstruct [
    :character_id,
    :alliance_id,
    :opts,
    server_online: true,
    start_time: nil,
    active_maps: [],
    is_online: false,
    track_online: true,
    track_location: true,
    track_ship: true,
    track_wallet: false,
    status: "new"
  ]

  @type t :: %__MODULE__{
          character_id: integer,
          opts: map,
          server_online: boolean,
          start_time: DateTime.t(),
          active_maps: [integer],
          is_online: boolean,
          track_online: boolean,
          track_location: boolean,
          track_ship: boolean,
          track_wallet: boolean,
          status: binary()
        }

  @online_error_timeout :timer.minutes(2)
  @forbidden_ttl :timer.minutes(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def init(args) do
    %{
      character_id: args[:character_id],
      start_time: DateTime.utc_now(),
      opts: args
    }
    |> new()
  end

  def update_track_settings(character_id, track_settings) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)

    {:ok,
     character_state
     |> _maybe_update_active_maps(track_settings)
     |> _maybe_stop_tracking(track_settings)
     |> _maybe_start_online_tracking(track_settings)
     |> _maybe_start_location_tracking(track_settings)
     |> _maybe_start_ship_tracking(track_settings)}
  end

  def update_info(character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
    _update_info(character_state)
  end

  def update_ship(character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
    _update_ship(character_state)
  end

  def update_location(character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
    _update_location(character_state)
  end

  def update_online(character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
    _update_online(character_state)
  end

  def check_online_errors(character_id) do
    case(WandererApp.Cache.lookup!("character:#{character_id}:online_error_time")) do
      nil ->
        :skip

      error_time ->
        duration = DateTime.diff(DateTime.utc_now(), error_time, :second)

        if duration >= @online_error_timeout do
          {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
          WandererApp.Cache.delete("character:#{character_id}:online_forbidden")
          WandererApp.Cache.delete("character:#{character_id}:online_error_time")
          WandererApp.Character.update_character(character_id, %{online: false})
          WandererApp.Cache.delete("character:#{character_id}:location_started")
          WandererApp.Cache.delete("character:#{character_id}:start_solar_system_id")

          WandererApp.Character.update_character_state(character_id, %{
            character_state
            | is_online: false,
              track_ship: false,
              track_location: false
          })

          :ok
        else
          :skip
        end
    end
  end

  def update_wallet(character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)
    _update_wallet(character_state)
  end

  defp _update_ship(%{character_id: character_id, track_ship: true} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token}} when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:ship_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          false ->
            case WandererApp.Esi.get_character_ship(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, ship} ->
                character_state |> _maybe_update_ship(ship)

                :ok

              {:error, :forbidden} ->
                Logger.warning("#{__MODULE__} failed to update_ship: forbidden")

                WandererApp.Cache.put(
                  "character:#{character_id}:ship_forbidden",
                  true,
                  ttl: @forbidden_ttl
                )

                {:error, :forbidden}

              {:error, error} ->
                Logger.error("#{__MODULE__} failed to update_ship: #{inspect(error)}")
                {:error, error}
            end
        end

      _ ->
        {:error, :skipped}
    end
  end

  defp _update_ship(_), do: {:error, :skipped}

  defp _update_online(%{track_online: true, character_id: character_id} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token}}
      when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          false ->
            case WandererApp.Esi.get_character_online(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, online} ->
                online = _get_online(online)

                WandererApp.Cache.delete("character:#{character_id}:online_forbidden")
                WandererApp.Cache.delete("character:#{character_id}:online_error_time")
                WandererApp.Character.update_character(character_id, online)

                if not online.online do
                  WandererApp.Cache.delete("character:#{character_id}:location_started")
                  WandererApp.Cache.delete("character:#{character_id}:start_solar_system_id")
                end

                update = %{
                  character_state
                  | is_online: online.online,
                    track_ship: online.online,
                    track_location: online.online
                }

                WandererApp.Character.update_character_state(character_id, update)

                :ok

              {:error, :forbidden} ->
                Logger.warning("#{__MODULE__} failed to update_online: forbidden")

                if not WandererApp.Cache.lookup!(
                     "character:#{character_id}:online_forbidden",
                     false
                   ) do
                  WandererApp.Cache.put(
                    "character:#{character_id}:online_forbidden",
                    true,
                    ttl: @forbidden_ttl
                  )

                  if is_nil(
                       WandererApp.Cache.lookup("character:#{character_id}:online_error_time")
                     ) do
                    WandererApp.Cache.insert(
                      "character:#{character_id}:online_error_time",
                      DateTime.utc_now()
                    )
                  end
                end

                :ok

              {:error, error} ->
                Logger.error("#{__MODULE__} failed to update_online: #{inspect(error)}")

                if is_nil(WandererApp.Cache.lookup("character:#{character_id}:online_error_time")) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:online_error_time",
                    DateTime.utc_now()
                  )
                end

                :ok
            end
        end

      _ ->
        {:error, :skipped}
    end
  end

  defp _update_online(_), do: {:error, :skipped}

  defp _update_location(%{track_location: true, character_id: character_id} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token}} when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:location_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          false ->
            case WandererApp.Esi.get_character_location(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, location} ->
                character_state
                |> _maybe_update_location(location)

                :ok

              {:error, :forbidden} ->
                Logger.warning("#{__MODULE__} failed to update_location: forbidden")

                WandererApp.Cache.put(
                  "character:#{character_id}:location_forbidden",
                  true,
                  ttl: @forbidden_ttl
                )

                {:error, :forbidden}

              {:error, error} ->
                Logger.error("#{__MODULE__} failed to update_location: #{inspect(error)}")
                {:error, error}
            end

          _ ->
            {:error, :skipped}
        end

      _ ->
        {:error, :skipped}
    end
  end

  defp _update_location(_), do: {:error, :skipped}

  defp _update_wallet(%{character_id: character_id} = state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token} = character}
      when not is_nil(access_token) ->
        character
        |> WandererApp.Character.can_track_wallet?()
        |> case do
          true ->
            WandererApp.Cache.has_key?("character:#{character_id}:wallet_forbidden")
            |> case do
              true ->
                {:error, :skipped}

              false ->
                case WandererApp.Esi.get_character_wallet(eve_id,
                       params: %{datasource: "tranquility"},
                       access_token: access_token,
                       character_id: character_id,
                       refresh_token?: true
                     ) do
                  {:ok, result} ->
                    state |> _maybe_update_wallet(result)

                    :ok

                  {:error, :forbidden} ->
                    Logger.warning("#{__MODULE__} failed to _update_wallet: forbidden")

                    WandererApp.Cache.put(
                      "character:#{character_id}:wallet_forbidden",
                      true,
                      ttl: @forbidden_ttl
                    )

                    {:error, :forbidden}

                  {:error, error} ->
                    Logger.error("#{__MODULE__} failed to _update_wallet: #{inspect(error)}")
                    {:error, error}
                end
            end

          _ ->
            {:error, :skipped}
        end

      _ ->
        {:error, :skipped}
    end
  end

  defp _update_info(%{character_id: character_id} = character_state) do
    {:ok, %{eve_id: eve_id}} = WandererApp.Character.get_character(character_id)

    WandererApp.Cache.has_key?("character:#{character_id}:info_forbidden")
    |> case do
      true ->
        {:error, :skipped}

      false ->
        case WandererApp.Esi.get_character_info(eve_id) do
          {:ok, info} ->
            update = character_state |> _maybe_update_corporation(info)
            WandererApp.Character.update_character_state(character_id, update)

            :ok

          {:error, :forbidden} ->
            Logger.warning("#{__MODULE__} failed to get_character_info: forbidden")

            WandererApp.Cache.put(
              "character:#{character_id}:info_forbidden",
              true,
              ttl: @forbidden_ttl
            )

            {:error, :forbidden}

          {:error, error} ->
            Logger.error("#{__MODULE__} failed to get_character_info: #{inspect(error)}")
            {:error, error}
        end
    end
  end

  defp _update_alliance(%{character_id: character_id} = state, alliance_id) do
    case WandererApp.Esi.get_alliance_info(alliance_id) do
      {:ok, %{"name" => alliance_name, "ticker" => alliance_ticker}} ->
        {:ok, character} = WandererApp.Character.get_character(character_id)

        character_update = %{
          alliance_id: alliance_id,
          alliance_name: alliance_name,
          alliance_ticker: alliance_ticker
        }

        {:ok, _character} =
          WandererApp.Api.Character.update_alliance(character, character_update)

        WandererApp.Character.update_character(character_id, character_update)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character:#{character_id}:alliance",
          {:character_alliance, {character_id, character_update}}
        )

        state

      _error ->
        Logger.error("Failed to get alliance info for #{alliance_id}")
        state
    end
  end

  defp _update_corporation(%{character_id: character_id} = state, corporation_id) do
    case WandererApp.Esi.get_corporation_info(corporation_id) do
      {:ok, %{"name" => corporation_name, "ticker" => corporation_ticker} = corporation_info} ->
        alliance_id = Map.get(corporation_info, "alliance_id")

        {:ok, character} =
          WandererApp.Character.get_character(character_id)

        character_update = %{
          corporation_id: corporation_id,
          corporation_name: corporation_name,
          corporation_ticker: corporation_ticker,
          alliance_id: alliance_id
        }

        {:ok, _character} =
          WandererApp.Api.Character.update_corporation(character, character_update)

        WandererApp.Character.update_character(character_id, character_update)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character:#{character_id}:corporation",
          {:character_corporation,
           {character_id,
            %{
              corporation_id: corporation_id,
              corporation_name: corporation_name,
              corporation_ticker: corporation_ticker
            }}}
        )

        state
        |> Map.merge(%{alliance_id: alliance_id, corporation_id: corporation_id})
        |> _maybe_update_alliance()

      _error ->
        Logger.warning("Failed to get corporation info for #{corporation_id}")
        state
    end
  end

  defp _maybe_update_ship(
         %{
           character_id: character_id
         } =
           state,
         ship
       ) do
    ship_type_id = Map.get(ship, "ship_type_id")
    ship_name = Map.get(ship, "ship_name")

    {:ok, %{ship: old_ship_type_id, ship_name: old_ship_name} = character} =
      WandererApp.Character.get_character(character_id)

    case old_ship_type_id != ship_type_id or old_ship_name != ship_name do
      true ->
        character_update = %{
          ship: ship_type_id,
          ship_name: ship_name
        }

        {:ok, _character} =
          WandererApp.Api.Character.update_ship(character, character_update)

        WandererApp.Character.update_character(character_id, character_update)

        state

      _ ->
        state
    end
  end

  defp _maybe_update_location(
         %{
           character_id: character_id
         } =
           state,
         location
       ) do
    location = _get_location(location)

    if not WandererApp.Cache.lookup!(
         "character:#{character_id}:location_started",
         false
       ) do
      WandererApp.Cache.lookup!("character:#{character_id}:start_solar_system_id", nil)
      |> case do
        nil ->
          WandererApp.Cache.put(
            "character:#{character_id}:start_solar_system_id",
            location.solar_system_id
          )

        start_solar_system_id ->
          if location.solar_system_id != start_solar_system_id do
            WandererApp.Cache.put(
              "character:#{character_id}:location_started",
              true
            )
          end
      end
    end

    {:ok, %{solar_system_id: solar_system_id, structure_id: structure_id} = character} =
      WandererApp.Character.get_character(character_id)

    WandererApp.Cache.lookup!(
      "character:#{character_id}:location_started",
      false
    )
    |> case do
      true ->
        case solar_system_id != location.solar_system_id or
               structure_id != location.structure_id do
          true ->
            {:ok, _character} = WandererApp.Api.Character.update_location(character, location)

            WandererApp.Character.update_character(character_id, location)

            :ok

          _ ->
            :ok
        end

      false ->
        {:ok, _character} = WandererApp.Api.Character.update_location(character, location)

        WandererApp.Character.update_character(character_id, location)

        :ok
    end

    state
  end

  defp _maybe_update_corporation(
         state,
         %{
           "corporation_id" => corporation_id
         } = _info
       ) do
    case corporation_id do
      nil ->
        state

      _ ->
        _update_corporation(state, corporation_id)
    end
  end

  defp _maybe_update_corporation(
         state,
         _info
       ),
       do: state

  defp _maybe_update_alliance(
         %{character_id: character_id, alliance_id: alliance_id} =
           state
       ) do
    case alliance_id do
      nil ->
        {:ok, character} = WandererApp.Character.get_character(character_id)

        character_update = %{
          alliance_id: nil,
          alliance_name: nil,
          alliance_ticker: nil
        }

        {:ok, _character} =
          Character.update_alliance(character, character_update)

        WandererApp.Character.update_character(character_id, character_update)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character:#{character_id}:alliance",
          {:character_alliance, {character_id, character_update}}
        )

        state

      _ ->
        _update_alliance(state, alliance_id)
    end
  end

  defp _maybe_update_wallet(
         %{character_id: character_id} =
           state,
         wallet_balance
       ) do
    {:ok, character} = WandererApp.Character.get_character(character_id)

    {:ok, _character} =
      WandererApp.Api.Character.update_wallet_balance(character, %{
        eve_wallet_balance: wallet_balance
      })

    WandererApp.Character.update_character(character_id, %{
      eve_wallet_balance: wallet_balance
    })

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character_id}",
      {:character_wallet_balance}
    )

    state
  end

  defp _maybe_start_online_tracking(
         state,
         %{track_online: true} = _track_settings
       ),
       do: %{
         state
         | track_online: true,
           track_location: true,
           track_ship: true
       }

  defp _maybe_start_online_tracking(
         state,
         _track_settings
       ),
       do: state

  defp _maybe_start_location_tracking(
         state,
         %{track_location: true} = _track_settings
       ) do
    %{state | track_location: true}
  end

  defp _maybe_start_location_tracking(
         state,
         _track_settings
       ),
       do: state

  defp _maybe_start_ship_tracking(
         state,
         %{track_ship: true} = _track_settings
       ),
       do: %{state | track_ship: true}

  defp _maybe_start_ship_tracking(
         state,
         _track_settings
       ),
       do: state

  defp _maybe_update_active_maps(
         %{character_id: character_id, active_maps: active_maps} =
           state,
         %{map_id: map_id, track: true} = _track_settings
       ) do
    WandererApp.Cache.put(
      "character:#{character_id}:map:#{map_id}:tracking_start_time",
      DateTime.utc_now()
    )

    WandererApp.Cache.take("character:#{character_id}:last_active_time")

    %{state | active_maps: [map_id | active_maps] |> Enum.uniq()}
  end

  defp _maybe_update_active_maps(
         %{character_id: character_id, active_maps: active_maps} = state,
         %{map_id: map_id, track: false} = _track_settings
       ) do
    case WandererApp.Cache.take("character:#{character_id}:map:#{map_id}:tracking_start_time") do
      start_time when not is_nil(start_time) ->
        duration = DateTime.diff(DateTime.utc_now(), start_time, :second)
        :telemetry.execute([:wanderer_app, :character, :tracker], %{duration: duration})

        :ok

      _ ->
        :ok
    end

    %{state | active_maps: Enum.filter(active_maps, &(&1 != map_id))}
  end

  defp _maybe_update_active_maps(
         state,
         _track_settings
       ),
       do: state

  defp _maybe_stop_tracking(
         %{active_maps: [], character_id: character_id, opts: opts} = state,
         _track_settings
       ) do
    if is_nil(opts[:keep_alive]) do
      WandererApp.Cache.put(
        "character:#{character_id}:last_active_time",
        DateTime.utc_now()
      )
    end

    WandererApp.Character.update_character(character_id, %{online: false})

    %{
      state
      | track_ship: false,
        track_online: false,
        track_location: false
    }
  end

  defp _maybe_stop_tracking(
         state,
         _track_settings
       ),
       do: state

  defp _get_location(%{"solar_system_id" => solar_system_id, "structure_id" => structure_id}) do
    %{solar_system_id: solar_system_id, structure_id: structure_id}
  end

  defp _get_location(%{"solar_system_id" => solar_system_id}) do
    %{solar_system_id: solar_system_id, structure_id: nil}
  end

  defp _get_location(_), do: %{solar_system_id: nil, structure_id: nil}

  defp _get_online(%{"online" => online}) do
    %{online: online}
  end

  defp _get_online(_), do: %{}
end
