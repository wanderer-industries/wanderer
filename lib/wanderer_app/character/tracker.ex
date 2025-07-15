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

  @pause_tracking_timeout :timer.minutes(60 * 10)
  @offline_timeout :timer.minutes(5)
  @online_error_timeout :timer.minutes(2)
  @ship_error_timeout :timer.minutes(2)
  @location_error_timeout :timer.minutes(2)
  @online_forbidden_ttl :timer.seconds(7)
  @online_limit_ttl :timer.seconds(7)
  @forbidden_ttl :timer.seconds(5)
  @limit_ttl :timer.seconds(5)
  @location_limit_ttl :timer.seconds(1)
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

  def check_offline(character_id) do
    WandererApp.Cache.lookup!("character:#{character_id}:last_online_time")
    |> case do
      nil ->
        WandererApp.Cache.insert(
          "character:#{character_id}:last_online_time",
          DateTime.utc_now()
        )

        :ok

      last_online_time ->
        duration = DateTime.diff(DateTime.utc_now(), last_online_time, :millisecond)

        if duration >= @offline_timeout do
          pause_tracking(character_id)

          :ok
        else
          :skip
        end
    end
  end

  def check_online_errors(character_id),
    do: check_tracking_errors(character_id, "online", @online_error_timeout)

  def check_ship_errors(character_id),
    do: check_tracking_errors(character_id, "ship", @ship_error_timeout)

  def check_location_errors(character_id),
    do: check_tracking_errors(character_id, "location", @location_error_timeout)

  defp check_tracking_errors(character_id, type, timeout) do
    WandererApp.Cache.lookup!("character:#{character_id}:#{type}_error_time")
    |> case do
      nil ->
        :skip

      error_time ->
        duration = DateTime.diff(DateTime.utc_now(), error_time, :millisecond)

        if duration >= timeout do
          pause_tracking(character_id)

          :ok
        else
          :skip
        end
    end
  end

  defp pause_tracking(character_id) do
    if WandererApp.Character.can_pause_tracking?(character_id) &&
         not WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused") do
      # Log character tracking statistics before pausing
      {:ok, character_state} = WandererApp.Character.get_character_state(character_id)

      Logger.warning(
        "CHARACTER_TRACKING_PAUSED: Character tracking paused due to sustained errors",
        character_id: character_id,
        active_maps: length(character_state.active_maps),
        is_online: character_state.is_online,
        tracking_duration_minutes: get_tracking_duration_minutes(character_id)
      )

      WandererApp.Cache.delete("character:#{character_id}:online_forbidden")
      WandererApp.Cache.delete("character:#{character_id}:online_error_time")
      WandererApp.Cache.delete("character:#{character_id}:ship_error_time")
      WandererApp.Cache.delete("character:#{character_id}:location_error_time")
      WandererApp.Character.update_character(character_id, %{online: false})

      WandererApp.Character.update_character_state(character_id, %{
        is_online: false
      })

      # Original log kept for backward compatibility
      Logger.warning("[CharacterTracker] paused for #{character_id}")

      WandererApp.Cache.put(
        "character:#{character_id}:tracking_paused",
        true,
        ttl: @pause_tracking_timeout
      )

      {:ok, %{solar_system_id: solar_system_id}} =
        WandererApp.Character.get_character(character_id)

      {:ok, %{active_maps: active_maps}} =
        WandererApp.Character.get_character_state(character_id)

      active_maps
      |> Enum.each(fn map_id ->
        WandererApp.Cache.put(
          "map:#{map_id}:character:#{character_id}:start_solar_system_id",
          solar_system_id
        )
      end)
    end
  end

  def update_settings(character_id, track_settings) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id)

    {:ok,
     character_state
     |> maybe_update_active_maps(track_settings)
     |> maybe_stop_tracking(track_settings)
     |> maybe_start_online_tracking(track_settings)
     |> maybe_start_location_tracking(track_settings)
     |> maybe_start_ship_tracking(track_settings)}
  end

  def update_online(character_id) when is_binary(character_id),
    do:
      character_id
      |> WandererApp.Character.get_character_state!()
      |> update_online()

  def update_online(%{track_online: true, character_id: character_id} = character_state) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token, tracking_pool: tracking_pool}}
      when not is_nil(access_token) ->
        (WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden") ||
           WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            # Monitor cache for potential evictions before ESI call
            log_cache_stats("character_online_check", character_id, "online_forbidden")

            case WandererApp.Esi.get_character_online(eve_id,
                   access_token: access_token,
                   character_id: character_id
                 ) do
              {:ok, online} ->
                online = get_online(online)

                if online.online == true do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:last_online_time",
                    DateTime.utc_now()
                  )
                end

                WandererApp.Cache.delete("character:#{character_id}:online_forbidden")
                WandererApp.Cache.delete("character:#{character_id}:online_error_time")
                WandererApp.Cache.delete("character:#{character_id}:ship_error_time")
                WandererApp.Cache.delete("character:#{character_id}:location_error_time")
                WandererApp.Cache.delete("character:#{character_id}:info_forbidden")
                WandererApp.Cache.delete("character:#{character_id}:ship_forbidden")
                WandererApp.Cache.delete("character:#{character_id}:location_forbidden")
                WandererApp.Cache.delete("character:#{character_id}:wallet_forbidden")

                try do
                  WandererApp.Character.update_character(character_id, online)
                rescue
                  error ->
                    Logger.error("DB_ERROR: Failed to update character in database",
                      character_id: character_id,
                      error: inspect(error),
                      operation: "update_character_online"
                    )

                    # Re-raise to maintain existing error handling
                    reraise error, __STACKTRACE__
                end

                update = %{
                  character_state
                  | is_online: online.online,
                    track_ship: online.online,
                    track_location: online.online
                }

                try do
                  WandererApp.Character.update_character_state(character_id, update)
                rescue
                  error ->
                    Logger.error("DB_ERROR: Failed to update character state in database",
                      character_id: character_id,
                      error: inspect(error),
                      operation: "update_character_state"
                    )

                    # Re-raise to maintain existing error handling
                    reraise error, __STACKTRACE__
                end

                :ok

              {:error, error} when error in [:forbidden, :not_found, :timeout] ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_online",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.warning("ESI_ERROR: Character online tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_online"
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:online_forbidden",
                  true,
                  ttl: @online_forbidden_ttl
                )

                if is_nil(
                     WandererApp.Cache.lookup!("character:#{character_id}:online_error_time")
                   ) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:online_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}

              {:error, :error_limited, headers} ->
                reset_timeout = get_reset_timeout(headers)

                reset_seconds =
                  Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()

                remaining =
                  Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

                # Emit telemetry for tracking
                :telemetry.execute(
                  [:wanderer_app, :esi, :rate_limited],
                  %{
                    reset_duration: reset_timeout,
                    count: 1
                  },
                  %{
                    endpoint: "character_online",
                    tracking_pool: tracking_pool,
                    character_id: character_id
                  }
                )

                Logger.warning("ESI_RATE_LIMITED: Character online tracking rate limited",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  endpoint: "character_online",
                  reset_seconds: reset_seconds,
                  remaining_requests: remaining
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:online_forbidden",
                  true,
                  ttl: reset_timeout
                )

                {:error, :skipped}

              {:error, error} ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_online",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.error("ESI_ERROR: Character online tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_online"
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:online_forbidden",
                  true,
                  ttl: @online_forbidden_ttl
                )

                if is_nil(
                     WandererApp.Cache.lookup!("character:#{character_id}:online_error_time")
                   ) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:online_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}

              _ ->
                {:error, :skipped}
            end
        end

      _ ->
        {:error, :skipped}
    end
  end

  def update_online(_), do: {:error, :skipped}

  defp get_reset_timeout(_headers, _default_timeout \\ @limit_ttl)

  defp get_reset_timeout(
         %{"x-esi-error-limit-remain" => ["0"], "x-esi-error-limit-reset" => [reset_seconds]},
         _default_timeout
       )
       when is_binary(reset_seconds),
       do: :timer.seconds((reset_seconds |> String.to_integer()) + 1)

  defp get_reset_timeout(_headers, default_timeout), do: default_timeout

  def update_info(character_id) do
    (WandererApp.Cache.has_key?("character:#{character_id}:info_forbidden") ||
       WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
    |> case do
      true ->
        {:error, :skipped}

      false ->
        {:ok, %{eve_id: eve_id, tracking_pool: tracking_pool}} =
          WandererApp.Character.get_character(character_id)

        case WandererApp.Esi.get_character_info(eve_id) do
          {:ok, _info} ->
            {:ok, character_state} = WandererApp.Character.get_character_state(character_id)

            update = maybe_update_corporation(character_state, eve_id |> String.to_integer())
            WandererApp.Character.update_character_state(character_id, update)

            :ok

          {:error, error} when error in [:forbidden, :not_found, :timeout] ->
            # Emit telemetry for tracking
            :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
              endpoint: "character_info",
              error_type: error,
              tracking_pool: tracking_pool,
              character_id: character_id
            })

            Logger.warning("ESI_ERROR: Character info tracking failed",
              character_id: character_id,
              tracking_pool: tracking_pool,
              error_type: error,
              endpoint: "character_info"
            )

            WandererApp.Cache.put(
              "character:#{character_id}:info_forbidden",
              true,
              ttl: @forbidden_ttl
            )

            {:error, error}

          {:error, :error_limited, headers} ->
            reset_timeout = get_reset_timeout(headers)

            reset_seconds =
              Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()

            remaining = Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

            # Emit telemetry for tracking
            :telemetry.execute(
              [:wanderer_app, :esi, :rate_limited],
              %{
                reset_duration: reset_timeout,
                count: 1
              },
              %{
                endpoint: "character_info",
                tracking_pool: tracking_pool,
                character_id: character_id
              }
            )

            Logger.warning("ESI_RATE_LIMITED: Character info tracking rate limited",
              character_id: character_id,
              tracking_pool: tracking_pool,
              endpoint: "character_info",
              reset_seconds: reset_seconds,
              remaining_requests: remaining
            )

            WandererApp.Cache.put(
              "character:#{character_id}:info_forbidden",
              true,
              ttl: reset_timeout
            )

            {:error, :error_limited}

          {:error, error} ->
            # Emit telemetry for tracking
            :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
              endpoint: "character_info",
              error_type: error,
              tracking_pool: tracking_pool,
              character_id: character_id
            })

            WandererApp.Cache.put(
              "character:#{character_id}:info_forbidden",
              true,
              ttl: @forbidden_ttl
            )

            Logger.error("ESI_ERROR: Character info tracking failed",
              character_id: character_id,
              tracking_pool: tracking_pool,
              error_type: error,
              endpoint: "character_info"
            )

            {:error, error}

          _ ->
            {:error, :skipped}
        end
    end
  end

  def update_ship(character_id) when is_binary(character_id),
    do:
      character_id
      |> WandererApp.Character.get_character_state!()
      |> update_ship()

  def update_ship(
        %{character_id: character_id, track_ship: true, is_online: true} = character_state
      ) do
    character_id
    |> WandererApp.Character.get_character()
    |> case do
      {:ok, %{eve_id: eve_id, access_token: access_token, tracking_pool: tracking_pool}}
      when not is_nil(access_token) ->
        (WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden") ||
           WandererApp.Cache.has_key?("character:#{character_id}:ship_forbidden") ||
           WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            case WandererApp.Esi.get_character_ship(eve_id,
                   access_token: access_token,
                   character_id: character_id
                 ) do
              {:ok, ship} when is_non_struct_map(ship) ->
                character_state |> maybe_update_ship(ship)

                :ok

              {:error, error} when error in [:forbidden, :not_found, :timeout] ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_ship",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.warning("ESI_ERROR: Character ship tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_ship"
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:ship_forbidden",
                  true,
                  ttl: @forbidden_ttl
                )

                if is_nil(WandererApp.Cache.lookup!("character:#{character_id}:ship_error_time")) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:ship_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, error}

              {:error, :error_limited, headers} ->
                reset_timeout = get_reset_timeout(headers)

                reset_seconds =
                  Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()

                remaining =
                  Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

                # Emit telemetry for tracking
                :telemetry.execute(
                  [:wanderer_app, :esi, :rate_limited],
                  %{
                    reset_duration: reset_timeout,
                    count: 1
                  },
                  %{
                    endpoint: "character_ship",
                    tracking_pool: tracking_pool,
                    character_id: character_id
                  }
                )

                Logger.warning("ESI_RATE_LIMITED: Character ship tracking rate limited",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  endpoint: "character_ship",
                  reset_seconds: reset_seconds,
                  remaining_requests: remaining
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:ship_forbidden",
                  true,
                  ttl: reset_timeout
                )

                {:error, :error_limited}

              {:error, error} ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_ship",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.error("ESI_ERROR: Character ship tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_ship"
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:ship_forbidden",
                  true,
                  ttl: @forbidden_ttl
                )

                if is_nil(WandererApp.Cache.lookup!("character:#{character_id}:ship_error_time")) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:ship_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, error}

              _ ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_ship",
                  error_type: "wrong_response",
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.error("ESI_ERROR: Character ship tracking failed - wrong response",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: "wrong_response",
                  endpoint: "character_ship"
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:ship_forbidden",
                  true,
                  ttl: @forbidden_ttl
                )

                if is_nil(WandererApp.Cache.lookup!("character:#{character_id}:ship_error_time")) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:ship_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}
            end
        end

      _ ->
        {:error, :skipped}
    end
  end

  def update_ship(_), do: {:error, :skipped}

  def update_location(character_id) when is_binary(character_id),
    do:
      character_id
      |> WandererApp.Character.get_character_state!()
      |> update_location()

  def update_location(
        %{track_location: true, is_online: true, character_id: character_id} = character_state
      ) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id, access_token: access_token, tracking_pool: tracking_pool}}
      when not is_nil(access_token) ->
        WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused")
        |> case do
          true ->
            {:error, :skipped}

          _ ->
            # Monitor cache for potential evictions before ESI call
            log_cache_stats("character_location_check", character_id, "location_forbidden")

            case WandererApp.Esi.get_character_location(eve_id,
                   access_token: access_token,
                   character_id: character_id
                 ) do
              {:ok, location} when is_non_struct_map(location) ->
                character_state
                |> maybe_update_location(location)

                :ok

              {:error, error} when error in [:forbidden, :not_found, :timeout] ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_location",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.warning("ESI_ERROR: Character location tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_location"
                )

                if is_nil(
                     WandererApp.Cache.lookup!("character:#{character_id}:location_error_time")
                   ) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:location_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}

              {:error, :error_limited, headers} ->
                reset_timeout = get_reset_timeout(headers, @location_limit_ttl)

                reset_seconds =
                  Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()

                remaining =
                  Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

                # Emit telemetry for tracking
                :telemetry.execute(
                  [:wanderer_app, :esi, :rate_limited],
                  %{
                    reset_duration: reset_timeout,
                    count: 1
                  },
                  %{
                    endpoint: "character_location",
                    tracking_pool: tracking_pool,
                    character_id: character_id
                  }
                )

                Logger.warning("ESI_RATE_LIMITED: Character location tracking rate limited",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  endpoint: "character_location",
                  reset_seconds: reset_seconds,
                  remaining_requests: remaining
                )

                WandererApp.Cache.put(
                  "character:#{character_id}:location_forbidden",
                  true,
                  ttl: reset_timeout
                )

                {:error, :error_limited}

              {:error, error} ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_location",
                  error_type: error,
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.error("ESI_ERROR: Character location tracking failed",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: error,
                  endpoint: "character_location"
                )

                if is_nil(
                     WandererApp.Cache.lookup!("character:#{character_id}:location_error_time")
                   ) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:location_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}

              _ ->
                # Emit telemetry for tracking
                :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                  endpoint: "character_location",
                  error_type: "wrong_response",
                  tracking_pool: tracking_pool,
                  character_id: character_id
                })

                Logger.error("ESI_ERROR: Character location tracking failed - wrong response",
                  character_id: character_id,
                  tracking_pool: tracking_pool,
                  error_type: "wrong_response",
                  endpoint: "character_location"
                )

                if is_nil(
                     WandererApp.Cache.lookup!("character:#{character_id}:location_error_time")
                   ) do
                  WandererApp.Cache.insert(
                    "character:#{character_id}:location_error_time",
                    DateTime.utc_now()
                  )
                end

                {:error, :skipped}
            end

          _ ->
            {:error, :skipped}
        end

      _ ->
        {:error, :skipped}
    end
  end

  def update_location(_), do: {:error, :skipped}

  def update_wallet(character_id) do
    character_id
    |> WandererApp.Character.get_character()
    |> case do
      {:ok,
       %{eve_id: eve_id, access_token: access_token, tracking_pool: tracking_pool} = character}
      when not is_nil(access_token) ->
        character
        |> WandererApp.Character.can_track_wallet?()
        |> case do
          true ->
            (WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden") ||
               WandererApp.Cache.has_key?("character:#{character_id}:wallet_forbidden") ||
               WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
            |> case do
              true ->
                {:error, :skipped}

              _ ->
                case WandererApp.Esi.get_character_wallet(eve_id,
                       params: %{datasource: "tranquility"},
                       access_token: access_token,
                       character_id: character_id
                     ) do
                  {:ok, result} ->
                    {:ok, state} = WandererApp.Character.get_character_state(character_id)
                    maybe_update_wallet(state, result)

                    :ok

                  {:error, error} when error in [:forbidden, :not_found, :timeout] ->
                    # Emit telemetry for tracking
                    :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                      endpoint: "character_wallet",
                      error_type: error,
                      tracking_pool: tracking_pool,
                      character_id: character_id
                    })

                    Logger.warning("ESI_ERROR: Character wallet tracking failed",
                      character_id: character_id,
                      tracking_pool: tracking_pool,
                      error_type: error,
                      endpoint: "character_wallet"
                    )

                    WandererApp.Cache.put(
                      "character:#{character_id}:wallet_forbidden",
                      true,
                      ttl: @forbidden_ttl
                    )

                    {:error, :skipped}

                  {:error, :error_limited, headers} ->
                    reset_timeout = get_reset_timeout(headers)

                    reset_seconds =
                      Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()

                    remaining =
                      Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

                    # Emit telemetry for tracking
                    :telemetry.execute(
                      [:wanderer_app, :esi, :rate_limited],
                      %{
                        reset_duration: reset_timeout,
                        count: 1
                      },
                      %{
                        endpoint: "character_wallet",
                        tracking_pool: tracking_pool,
                        character_id: character_id
                      }
                    )

                    Logger.warning("ESI_RATE_LIMITED: Character wallet tracking rate limited",
                      character_id: character_id,
                      tracking_pool: tracking_pool,
                      endpoint: "character_wallet",
                      reset_seconds: reset_seconds,
                      remaining_requests: remaining
                    )

                    WandererApp.Cache.put(
                      "character:#{character_id}:wallet_forbidden",
                      true,
                      ttl: reset_timeout
                    )

                    {:error, :skipped}

                  {:error, error} ->
                    # Emit telemetry for tracking
                    :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                      endpoint: "character_wallet",
                      error_type: error,
                      tracking_pool: tracking_pool,
                      character_id: character_id
                    })

                    Logger.error("ESI_ERROR: Character wallet tracking failed",
                      character_id: character_id,
                      tracking_pool: tracking_pool,
                      error_type: error,
                      endpoint: "character_wallet"
                    )

                    WandererApp.Cache.put(
                      "character:#{character_id}:wallet_forbidden",
                      true,
                      ttl: @forbidden_ttl
                    )

                    {:error, :skipped}

                  error ->
                    # Emit telemetry for tracking
                    :telemetry.execute([:wanderer_app, :esi, :error], %{count: 1}, %{
                      endpoint: "character_wallet",
                      error_type: error,
                      tracking_pool: tracking_pool,
                      character_id: character_id
                    })

                    Logger.error("ESI_ERROR: Character wallet tracking failed",
                      character_id: character_id,
                      tracking_pool: tracking_pool,
                      error_type: error,
                      endpoint: "character_wallet"
                    )

                    WandererApp.Cache.put(
                      "character:#{character_id}:wallet_forbidden",
                      true,
                      ttl: @forbidden_ttl
                    )

                    {:error, :skipped}
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
    (WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden") ||
       WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
    |> case do
      true ->
        state

      _ ->
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
  end

  defp update_corporation(%{character_id: character_id} = state, corporation_id) do
    (WandererApp.Cache.has_key?("character:#{character_id}:online_forbidden") ||
       WandererApp.Cache.has_key?("character:#{character_id}:tracking_paused"))
    |> case do
      true ->
        state

      _ ->
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
  end

  defp maybe_update_ship(
         %{
           character_id: character_id
         } =
           state,
         ship
       )
       when is_non_struct_map(ship) do
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

  defp maybe_update_ship(
         state,
         _ship
       ),
       do: state

  defp maybe_update_location(
         %{
           character_id: character_id
         } =
           state,
         location
       ) do
    location = get_location(location)

    {:ok,
     %{solar_system_id: solar_system_id, structure_id: structure_id, station_id: station_id} =
       character} =
      WandererApp.Character.get_character(character_id)

    is_location_updated?(location, solar_system_id, structure_id, station_id)
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

  defp is_location_updated?(
         %{
           solar_system_id: new_solar_system_id,
           station_id: new_station_id,
           structure_id: new_structure_id
         } = _location,
         solar_system_id,
         structure_id,
         station_id
       ),
       do:
         solar_system_id != new_solar_system_id ||
           structure_id != new_structure_id ||
           station_id != new_station_id

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
         %{map_id: map_id, track: true} = track_settings
       ) do
    if not Enum.member?(active_maps, map_id) do
      WandererApp.Cache.put(
        "character:#{character_id}:map:#{map_id}:tracking_start_time",
        DateTime.utc_now()
      )

      WandererApp.Cache.put(
        "map:#{map_id}:character:#{character_id}:start_solar_system_id",
        track_settings |> Map.get(:solar_system_id)
      )

      WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
      WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:station_id")
      WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:structure_id")

      WandererApp.Cache.take("character:#{character_id}:last_active_time")

      %{state | active_maps: [map_id | active_maps]}
    else
      WandererApp.Cache.take("character:#{character_id}:last_active_time")

      state
    end
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

    state
  end

  defp maybe_stop_tracking(
         state,
         _track_settings
       ),
       do: state

  defp get_location(%{
         "solar_system_id" => solar_system_id,
         "station_id" => station_id
       }),
       do: %{solar_system_id: solar_system_id, structure_id: nil, station_id: station_id}

  defp get_location(%{
         "solar_system_id" => solar_system_id,
         "structure_id" => structure_id
       }),
       do: %{solar_system_id: solar_system_id, structure_id: structure_id, station_id: nil}

  defp get_location(%{"solar_system_id" => solar_system_id}),
    do: %{solar_system_id: solar_system_id, structure_id: nil, station_id: nil}

  defp get_location(_), do: %{solar_system_id: nil, structure_id: nil, station_id: nil}

  defp get_online(%{"online" => online}), do: %{online: online}

  defp get_online(_), do: %{online: false}

  defp get_tracking_duration_minutes(character_id) do
    case WandererApp.Cache.lookup!("character:#{character_id}:map:*:tracking_start_time") do
      nil ->
        0

      start_time when is_struct(start_time, DateTime) ->
        DateTime.diff(DateTime.utc_now(), start_time, :minute)

      _ ->
        0
    end
  end

  # Add cache monitoring for eviction detection
  defp log_cache_stats(operation, character_id, cache_key) do
    try do
      # Check if critical cache entries are missing (could indicate eviction)
      critical_keys = [
        "character:#{character_id}:last_online_time",
        "character:#{character_id}:online_forbidden",
        "character:#{character_id}:location_forbidden",
        "character:#{character_id}:ship_forbidden"
      ]

      missing_keys =
        Enum.filter(critical_keys, fn key ->
          not WandererApp.Cache.has_key?(key)
        end)

      # Alert if multiple cache keys are missing
      if length(missing_keys) > 2 do
        Logger.warning("CACHE_EVICTION_SUSPECTED: Multiple critical cache keys missing",
          operation: operation,
          character_id: character_id,
          cache_key: cache_key,
          missing_keys: missing_keys,
          missing_count: length(missing_keys)
        )

        # Emit telemetry
        :telemetry.execute(
          [:wanderer_app, :cache, :eviction_suspected],
          %{
            missing_count: length(missing_keys)
          },
          %{
            operation: operation,
            character_id: character_id
          }
        )
      end
    rescue
      # Don't fail character tracking if cache monitoring fails
      _ -> :ok
    end
  end

  # Telemetry handler for database pool monitoring
  def handle_pool_query(_event_name, measurements, metadata, _config) do
    queue_time = measurements[:queue_time]

    # Check if queue_time exists and exceeds threshold (in microseconds)
    # 100ms = 100_000 microseconds indicates pool exhaustion
    if queue_time && queue_time > 100_000 do
      Logger.warning("DB_POOL_EXHAUSTED: Database pool contention detected",
        queue_time_ms: div(queue_time, 1000),
        query: metadata[:query],
        source: metadata[:source],
        repo: metadata[:repo]
      )
    end
  end
end
