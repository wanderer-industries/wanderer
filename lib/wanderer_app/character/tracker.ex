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
  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

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
     |> maybe_update_active_maps(track_settings)
     |> maybe_stop_tracking(track_settings)
     |> maybe_start_online_tracking(track_settings)
     |> maybe_start_location_tracking(track_settings)
     |> maybe_start_ship_tracking(track_settings)}
  end

  def update_info(character_id) do
    WandererApp.Cache.has_key?("character:#{character_id}:info_forbidden")
    |> case do
      true ->
        {:error, :skipped}

      false ->
        {:ok, %{eve_id: eve_id}} = WandererApp.Character.get_character(character_id)

        case WandererApp.Esi.get_character_info(eve_id) do
          {:ok, _info} ->
            {:ok, character_state} = WandererApp.Character.get_character_state(character_id)

            update = maybe_update_corporation(character_state, eve_id |> String.to_integer())
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

  def update_ship(character_id) when is_binary(character_id) do
    character_id
    |> WandererApp.Character.get_character_state!()
    |> update_ship()
  end

  def update_ship(%{character_id: character_id, track_ship: true} = character_state) do
    character_id
    |> WandererApp.Character.get_character()
    |> case do
      {:ok, %{eve_id: eve_id, access_token: access_token}} when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:ship_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            case WandererApp.Esi.get_character_ship(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, ship} ->
                character_state |> maybe_update_ship(ship)

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

  def update_ship(_), do: {:error, :skipped}

  def update_location(character_id) when is_binary(character_id) do
    character_id
    |> WandererApp.Character.get_character_state!()
    |> update_location()
  end

  def update_location(%{track_location: true, character_id: character_id} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token}} when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:location_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            case WandererApp.Esi.get_character_location(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, location} ->
                character_state
                |> maybe_update_location(location)

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
        end

      _ ->
        {:error, :skipped}
    end
  end

  def update_location(_), do: {:error, :skipped}

  def update_online(character_id) when is_binary(character_id) do
    character_id
    |> WandererApp.Character.get_character_state!()
    |> update_online()
  end

  def update_online(%{track_online: true, character_id: character_id} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token}}
      when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden")
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            case WandererApp.Esi.get_character_online(eve_id,
                   access_token: access_token,
                   character_id: character_id,
                   refresh_token?: true
                 ) do
              {:ok, online} ->
                online = get_online(online)

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

  def update_online(_), do: {:error, :skipped}

  def check_online_errors(character_id) do
    WandererApp.Cache.lookup!("character:#{character_id}:online_error_time")
    |> case do
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
    character_id
    |> WandererApp.Character.get_character()
    |> case do
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

              _ ->
                case WandererApp.Esi.get_character_wallet(eve_id,
                       params: %{datasource: "tranquility"},
                       access_token: access_token,
                       character_id: character_id,
                       refresh_token?: true
                     ) do
                  {:ok, result} ->
                    {:ok, state} = WandererApp.Character.get_character_state(character_id)
                    maybe_update_wallet(state, result)

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

  defp update_alliance(%{character_id: character_id} = state, alliance_id) do
    alliance_id
    |> WandererApp.Esi.get_alliance_info()
    |> case do
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

        @pubsub_client.broadcast(
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

  defp update_corporation(%{character_id: character_id} = state, corporation_id) do
    corporation_id
    |> WandererApp.Esi.get_corporation_info()
    |> case do
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

        @pubsub_client.broadcast(
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
        |> maybe_update_alliance()

      error ->
        Logger.warning(
          "Failed to get corporation info for character #{character_id}: #{inspect(error)}",
          character_id: character_id,
          corporation_id: corporation_id
        )

        state
    end
  end

  defp maybe_update_ship(
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

    ship_updated = old_ship_type_id != ship_type_id || old_ship_name != ship_name

    if ship_updated do
      character_update = %{
        ship: ship_type_id,
        ship_name: ship_name
      }

      {:ok, _character} =
        WandererApp.Api.Character.update_ship(character, character_update)

      WandererApp.Character.update_character(character_id, character_update)
    end

    state
  end

  defp maybe_update_location(
         %{
           character_id: character_id,
         } =
           state,
         location
       ) do
    location = get_location(location)

    if not is_location_started?(character_id) do
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

    (not is_location_started?(character_id) ||
       is_location_updated?(location, solar_system_id, structure_id))
    |> case do
      true ->
        {:ok, _character} = WandererApp.Api.Character.update_location(character, location)

        WandererApp.Character.update_character(character_id, location)

        :ok

      _ ->
        :ok
    end

    state
  end

  defp is_location_started?(character_id),
    do:
      WandererApp.Cache.lookup!(
        "character:#{character_id}:location_started",
        false
      )

  defp is_location_updated?(location, solar_system_id, structure_id),
    do:
      solar_system_id != location.solar_system_id ||
        structure_id != location.structure_id

  defp maybe_update_corporation(
         state,
         character_eve_id
       )
       when not is_nil(character_eve_id) and is_integer(character_eve_id) do
    case WandererApp.Esi.post_characters_affiliation([character_eve_id]) do
      {:ok, [character_aff_info]} when not is_nil(character_aff_info) ->
        update_corporation(state, character_aff_info |> Map.get("corporation_id"))

      _error ->
        state
    end
  end

  defp maybe_update_corporation(
         state,
         _info
       ),
       do: state

  defp maybe_update_alliance(
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

        @pubsub_client.broadcast(
          WandererApp.PubSub,
          "character:#{character_id}:alliance",
          {:character_alliance, {character_id, character_update}}
        )

        state

      _ ->
        update_alliance(state, alliance_id)
    end
  end

  defp maybe_update_wallet(
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

    @pubsub_client.broadcast(
      WandererApp.PubSub,
      "character:#{character_id}",
      {:character_wallet_balance}
    )

    state
  end

  defp maybe_start_online_tracking(
         state,
         %{track_online: true} = _track_settings
       ),
       do: %{
         state
         | track_online: true,
           track_location: true,
           track_ship: true
       }

  defp maybe_start_online_tracking(
         state,
         _track_settings
       ),
       do: state

  defp maybe_start_location_tracking(
         state,
         %{track_location: true} = _track_settings
       ),
       do: %{state | track_location: true}

  defp maybe_start_location_tracking(
         state,
         _track_settings
       ),
       do: state

  defp maybe_start_ship_tracking(
         state,
         %{track_ship: true} = _track_settings
       ),
       do: %{state | track_ship: true}

  defp maybe_start_ship_tracking(
         state,
         _track_settings
       ),
       do: state

  defp maybe_update_active_maps(
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

  defp maybe_update_active_maps(
         %{character_id: character_id, active_maps: active_maps} = state,
         %{map_id: map_id, track: false} = _track_settings
       ) do
    WandererApp.Cache.take("character:#{character_id}:map:#{map_id}:tracking_start_time")
    |> case do
      start_time when not is_nil(start_time) ->
        duration = DateTime.diff(DateTime.utc_now(), start_time, :second)
        :telemetry.execute([:wanderer_app, :character, :tracker], %{duration: duration})

        :ok

      _ ->
        :ok
    end

    %{state | active_maps: Enum.filter(active_maps, &(&1 != map_id))}
  end

  defp maybe_update_active_maps(
         state,
         _track_settings
       ),
       do: state

  defp maybe_stop_tracking(
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

  defp maybe_stop_tracking(
         state,
         _track_settings
       ),
       do: state

  defp get_location(%{"solar_system_id" => solar_system_id, "structure_id" => structure_id}),
    do: %{solar_system_id: solar_system_id, structure_id: structure_id}

  defp get_location(%{"solar_system_id" => solar_system_id}),
    do: %{solar_system_id: solar_system_id, structure_id: nil}

  defp get_location(_), do: %{solar_system_id: nil, structure_id: nil}

  defp get_online(%{"online" => online}), do: %{online: online}

  defp get_online(_), do: %{}
end
