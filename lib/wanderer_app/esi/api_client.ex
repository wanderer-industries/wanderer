defmodule WandererApp.Esi.ApiClient do
  use Nebulex.Caching
  @moduledoc false

  require Logger
  alias WandererApp.Cache

  @ttl :timer.hours(1)
  @routes_ttl :timer.minutes(15)

  @base_url "https://esi.evetech.net/latest"
  @wanderrer_user_agent "(wanderer-industries@proton.me; +https://github.com/wanderer-industries/wanderer)"

  @req_esi Req.new(base_url: @base_url, finch: WandererApp.Finch)

  @get_link_pairs_advanced_params [
    :include_mass_crit,
    :include_eol,
    :include_frig
  ]

  @default_routes_settings %{
    path_type: "shortest",
    include_mass_crit: true,
    include_eol: false,
    include_frig: true,
    include_cruise: true,
    avoid_wormholes: false,
    avoid_pochven: false,
    avoid_edencom: false,
    avoid_triglavian: false,
    include_thera: true,
    avoid: []
  }

  @zarzakh_system 30_100_000
  @default_avoid_systems [@zarzakh_system]

  @cache_opts [cache: true]
  @retry_opts [retry: false, retry_log_level: :warning]
  @timeout_opts [pool_timeout: 15_000, receive_timeout: :timer.minutes(1)]
  @api_retry_count 1

  @logger Application.compile_env(:wanderer_app, :logger)

  def get_server_status, do: get("/status")

  def set_autopilot_waypoint(add_to_beginning, clear_other_waypoints, destination_id, opts \\ []),
    do:
      post_esi(
        "/ui/autopilot/waypoint",
        get_auth_opts(opts)
        |> Keyword.merge(
          params: %{
            add_to_beginning: add_to_beginning,
            clear_other_waypoints: clear_other_waypoints,
            destination_id: destination_id
          }
        )
      )

  def post_characters_affiliation(character_eve_ids, _opts)
      when is_list(character_eve_ids),
      do:
        post_esi(
          "/characters/affiliation/",
          json: character_eve_ids,
          params: %{
            datasource: "tranquility"
          }
        )

  def find_routes(map_id, origin, hubs, routes_settings) do
    origin = origin |> String.to_integer()
    hubs = hubs |> Enum.map(&(&1 |> String.to_integer()))

    routes_settings = @default_routes_settings |> Map.merge(routes_settings)

    connections =
      case routes_settings.avoid_wormholes do
        false ->
          map_chains =
            routes_settings
            |> Map.take(@get_link_pairs_advanced_params)
            |> Map.put_new(:map_id, map_id)
            |> WandererApp.Api.MapConnection.get_link_pairs_advanced!()
            |> Enum.map(fn %{
                             solar_system_source: solar_system_source,
                             solar_system_target: solar_system_target
                           } ->
              %{
                first: solar_system_source,
                second: solar_system_target
              }
            end)
            |> Enum.uniq()

          {:ok, thera_chains} =
            case routes_settings.include_thera do
              true ->
                WandererApp.Server.TheraDataFetcher.get_chain_pairs(routes_settings)

              false ->
                {:ok, []}
            end

          chains = remove_intersection([map_chains | thera_chains] |> List.flatten())

          chains =
            case routes_settings.include_cruise do
              false ->
                {:ok, wh_class_a_systems} = WandererApp.CachedInfo.get_wh_class_a_systems()

                chains
                |> Enum.filter(fn x ->
                  not Enum.member?(wh_class_a_systems, x.first) and
                    not Enum.member?(wh_class_a_systems, x.second)
                end)

              _ ->
                chains
            end

          chains
          |> Enum.map(fn chain ->
            ["#{chain.first}|#{chain.second}", "#{chain.second}|#{chain.first}"]
          end)
          |> List.flatten()

        true ->
          []
      end

    {:ok, trig_systems} = WandererApp.CachedInfo.get_trig_systems()

    pochven_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Final" end)
      |> Enum.map(& &1.solar_system_id)

    triglavian_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Triglavian" end)
      |> Enum.map(& &1.solar_system_id)

    edencom_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Edencom" end)
      |> Enum.map(& &1.solar_system_id)

    avoidance_list =
      case routes_settings.avoid_edencom do
        true ->
          edencom_solar_systems

        false ->
          []
      end

    avoidance_list =
      case routes_settings.avoid_triglavian do
        true ->
          [avoidance_list | triglavian_solar_systems]

        false ->
          avoidance_list
      end

    avoidance_list =
      case routes_settings.avoid_pochven do
        true ->
          [avoidance_list | pochven_solar_systems]

        false ->
          avoidance_list
      end

    avoidance_list =
      (@default_avoid_systems ++ [routes_settings.avoid | avoidance_list])
      |> List.flatten()
      |> Enum.uniq()

    params =
      %{
        datasource: "tranquility",
        flag: routes_settings.path_type,
        connections: connections,
        avoid: avoidance_list
      }

    {:ok, all_routes} = get_all_routes(hubs, origin, params)

    routes =
      all_routes
      |> Enum.map(fn route_info ->
        map_route_info(route_info)
      end)
      |> Enum.filter(fn route_info -> not is_nil(route_info) end)

    {:ok, routes}
  end

  def get_all_routes(hubs, origin, params, opts \\ []) do
    cache_key =
      "routes-#{origin}-#{hubs |> Enum.join("-")}-#{:crypto.hash(:sha, :erlang.term_to_binary(params))}"

    case WandererApp.Cache.lookup(cache_key) do
      {:ok, result} when not is_nil(result) ->
        {:ok, result}

      _ ->
        case get_all_routes_custom(hubs, origin, params) do
          {:ok, result} ->
            WandererApp.Cache.insert(
              cache_key,
              result,
              ttl: @routes_ttl
            )

            {:ok, result}

          {:error, _error} ->
            @logger.error(
              "Error getting custom routes for #{inspect(origin)}: #{inspect(params)}"
            )

            get_all_routes_eve(hubs, origin, params, opts)
        end
    end
  end

  defp get_all_routes_custom(hubs, origin, params),
    do:
      post(
        "#{get_custom_route_base_url()}/route/multiple",
        [
          json: %{
            origin: origin,
            destinations: hubs,
            flag: params.flag,
            connections: params.connections,
            avoid: params.avoid
          }
        ]
        |> Keyword.merge(@timeout_opts)
      )

  def get_all_routes_eve(hubs, origin, params, opts),
    do:
      {:ok,
       hubs
       |> Task.async_stream(
         fn destination ->
           get_routes(origin, destination, params, opts)
         end,
         max_concurrency: System.schedulers_online() * 4,
         timeout: :timer.seconds(30),
         on_timeout: :kill_task
       )
       |> Enum.map(fn result ->
         case result do
           {:ok, val} -> val
           {:error, error} -> {:error, error}
           _ -> {:error, :failed}
         end
       end)}

  def get_routes(origin, destination, params, opts) do
    case _get_routes(origin, destination, params, opts) do
      {:ok, result} ->
        %{
          "origin" => origin,
          "destination" => destination,
          "systems" => result,
          "success" => true
        }

      error ->
        Logger.warning("Error getting routes: #{inspect(error)}")
        %{"origin" => origin, "destination" => destination, "systems" => [], "success" => false}
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "info-#{eve_id}",
              opts: [ttl: @ttl]
            )
  def get_alliance_info(eve_id, opts \\ []) do
    case get_alliance_info(eve_id, "", opts) do
      {:ok, result} when is_map(result) -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
      error -> error
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "killmail-#{killmail_id}-#{killmail_hash}",
              opts: [ttl: @ttl]
            )
  def get_killmail(killmail_id, killmail_hash, opts \\ []) do
    get("/killmails/#{killmail_id}/#{killmail_hash}/", opts, @cache_opts)
  end

  @decorate cacheable(
              cache: Cache,
              key: "info-#{eve_id}",
              opts: [ttl: @ttl]
            )
  def get_corporation_info(eve_id, opts \\ []) do
    case get_corporation_info(eve_id, "", opts) do
      {:ok, result} when is_map(result) -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
      error -> error
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "info-#{eve_id}",
              opts: [ttl: @ttl]
            )
  def get_character_info(eve_id, opts \\ []) do
    case get(
           "/characters/#{eve_id}/",
           opts,
           @cache_opts
         ) do
      {:ok, result} when is_map(result) -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
      error -> error
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "get_custom_route_base_url"
            )
  def get_custom_route_base_url, do: WandererApp.Env.custom_route_base_url()

  def get_character_wallet(character_eve_id, opts \\ []),
    do: get_character_auth_data(character_eve_id, "wallet", opts ++ @cache_opts)

  def get_corporation_wallets(corporation_id, opts \\ []),
    do: get_corporation_auth_data(corporation_id, "wallets", opts)

  def get_corporation_wallet_journal(corporation_id, division, opts \\ []),
    do:
      get_corporation_auth_data(
        corporation_id,
        "wallets/#{division}/journal",
        opts
      )

  def get_corporation_wallet_transactions(corporation_id, division, opts \\ []),
    do:
      get_corporation_auth_data(
        corporation_id,
        "wallets/#{division}/transactions",
        opts
      )

  def get_character_location(character_eve_id, opts \\ []),
    do: get_character_auth_data(character_eve_id, "location", opts ++ @cache_opts)

  def get_character_online(character_eve_id, opts \\ []),
    do: get_character_auth_data(character_eve_id, "online", opts ++ @cache_opts)

  def get_character_ship(character_eve_id, opts \\ []),
    do: get_character_auth_data(character_eve_id, "ship", opts ++ @cache_opts)

  def search(character_eve_id, opts \\ []) do
    search_val = to_string(opts[:params][:search] || "")
    categories_val = to_string(opts[:params][:categories] || "character,alliance,corporation")

    query_params = [
      {"search", search_val},
      {"categories", categories_val},
      {"language", "en-us"},
      {"strict", "false"},
      {"datasource", "tranquility"}
    ]

    merged_opts = Keyword.put(opts, :params, query_params)
    get_search(character_eve_id, search_val, categories_val, merged_opts)
  end

  @decorate cacheable(
              cache: Cache,
              key: "search-#{character_eve_id}-#{categories_val}-#{search_val |> Slug.slugify()}",
              opts: [ttl: @ttl]
            )
  defp get_search(character_eve_id, search_val, categories_val, merged_opts) do
    get_character_auth_data(character_eve_id, "search", merged_opts)
  end

  defp remove_intersection(pairs_arr) do
    tuples = pairs_arr |> Enum.map(fn x -> {x.first, x.second} end)

    tuples
    |> Enum.reduce([], fn {first, second} = x, acc ->
      if Enum.member?(tuples, {second, first}) do
        acc
      else
        [x | acc]
      end
    end)
    |> Enum.uniq()
    |> Enum.map(fn {first, second} ->
      %{
        first: first,
        second: second
      }
    end)
  end

  defp _get_routes(origin, destination, params, opts),
    do: get_routes_eve(origin, destination, params, opts)

  defp get_routes_eve(origin, destination, params, opts) do
    esi_params =
      Map.merge(params, %{
        connections: params.connections |> Enum.join(","),
        avoid: params.avoid |> Enum.join(",")
      })

    get(
      "/route/#{origin}/#{destination}/?#{esi_params |> Plug.Conn.Query.encode()}",
      opts,
      @cache_opts
    )
  end

  defp get_auth_opts(opts), do: [auth: {:bearer, opts[:access_token]}]

  defp get_alliance_info(alliance_eve_id, info_path, opts),
    do:
      get(
        "/alliances/#{alliance_eve_id}/#{info_path}",
        opts,
        @cache_opts
      )

  defp get_corporation_info(corporation_eve_id, info_path, opts),
    do:
      get(
        "/corporations/#{corporation_eve_id}/#{info_path}",
        opts,
        @cache_opts
      )

  defp get_character_auth_data(character_eve_id, info_path, opts) do
    path = "/characters/#{character_eve_id}/#{info_path}"

    auth_opts =
      [params: opts[:params] || []] ++
        (opts |> get_auth_opts())

    character_id = opts |> Keyword.get(:character_id, nil)

    if not is_access_token_expired?(character_id) do
      get(
        path,
        auth_opts,
        opts |> with_refresh_token()
      )
    else
      get_retry(path, auth_opts, opts |> with_refresh_token())
    end
  end

  defp is_access_token_expired?(character_id) do
    {:ok, %{expires_at: expires_at} = _character} =
      WandererApp.Character.get_character(character_id)

    now = DateTime.utc_now() |> DateTime.to_unix()

    expires_at - now <= 0
  end

  defp get_corporation_auth_data(corporation_eve_id, info_path, opts),
    do:
      get(
        "/corporations/#{corporation_eve_id}/#{info_path}",
        [params: opts[:params] || []] ++
          (opts |> get_auth_opts()),
        (opts |> with_refresh_token()) ++ @cache_opts
      )

  defp with_user_agent_opts(opts) do
    opts
    |> Keyword.merge(
      headers: [{:user_agent, "Wanderer/#{WandererApp.Env.vsn()} #{@wanderrer_user_agent}"}]
    )
  end

  defp with_refresh_token(opts) do
    opts |> Keyword.merge(refresh_token?: true)
  end

  defp with_cache_opts(opts) do
    opts |> Keyword.merge(@cache_opts) |> Keyword.merge(cache_dir: System.tmp_dir!())
  end

  defp get(path, api_opts \\ [], opts \\ []) do
    case Cachex.get(:api_cache, path) do
      {:ok, cached_data} when not is_nil(cached_data) ->
        {:ok, cached_data}

      _ ->
        do_get_request(path, api_opts, opts)
    end
  end

  defp do_get_request(path, api_opts \\ [], opts \\ []) do
    try do
      case Req.get(
             @req_esi,
             api_opts
             |> Keyword.merge(url: path)
             |> with_user_agent_opts()
             |> with_cache_opts()
             |> Keyword.merge(@retry_opts)
             |> Keyword.merge(@timeout_opts)
           ) do
        {:ok, %{status: 200, body: body, headers: headers}} ->
          maybe_cache_response(path, body, headers, opts)

          {:ok, body}

        {:ok, %{status: 504}} ->
          {:error, :timeout}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: 420, headers: headers} = _error} ->
          # Extract rate limit information from headers
          reset_seconds = Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()
          remaining = Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

          # Emit telemetry for rate limiting
          :telemetry.execute(
            [:wanderer_app, :esi, :rate_limited],
            %{
              count: 1,
              reset_duration:
                case Integer.parse(reset_seconds || "0") do
                  {seconds, _} -> seconds * 1000
                  _ -> 0
                end
            },
            %{
              method: "GET",
              path: path,
              reset_seconds: reset_seconds,
              remaining_requests: remaining
            }
          )

          Logger.warning("ESI_RATE_LIMITED: GET request rate limited",
            method: "GET",
            path: path,
            reset_seconds: reset_seconds,
            remaining_requests: remaining
          )

          {:error, :error_limited, headers}

        {:ok, %{status: status} = _error} when status in [401, 403] ->
          get_retry(path, api_opts, opts)

        {:ok, %{status: status}} ->
          {:error, "Unexpected status: #{status}"}

        {:error, _reason} ->
          {:error, "Request failed"}
      end
    rescue
      e ->
        Logger.error(Exception.message(e))

        {:error, "Request failed"}
    end
  end

  defp maybe_cache_response(path, body, %{"expires" => [expires]}, opts)
       when is_binary(path) and not is_nil(expires) do
    try do
      if opts |> Keyword.get(:cache, false) do
        cached_ttl =
          DateTime.diff(Timex.parse!(expires, "{RFC1123}"), DateTime.utc_now(), :millisecond)

        Cachex.put(
          :api_cache,
          path,
          body,
          ttl: cached_ttl
        )
      end
    rescue
      e ->
        @logger.error(Exception.message(e))

        :ok
    end
  end

  defp maybe_cache_response(_path, _body, _headers, _opts), do: :ok

  defp post(url, opts) do
    try do
      case Req.post("#{url}", opts |> with_user_agent_opts()) do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          {:ok, body}

        {:ok, %{status: 504}} ->
          {:error, :timeout}

        {:ok, %{status: 403}} ->
          {:error, :forbidden}

        {:ok, %{status: 420, headers: headers} = _error} ->
          # Extract rate limit information from headers
          reset_seconds = Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()
          remaining = Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

          # Emit telemetry for rate limiting
          :telemetry.execute(
            [:wanderer_app, :esi, :rate_limited],
            %{
              count: 1,
              reset_duration:
                case Integer.parse(reset_seconds || "0") do
                  {seconds, _} -> seconds * 1000
                  _ -> 0
                end
            },
            %{
              method: "POST",
              path: url,
              reset_seconds: reset_seconds,
              remaining_requests: remaining
            }
          )

          Logger.warning("ESI_RATE_LIMITED: POST request rate limited",
            method: "POST",
            path: url,
            reset_seconds: reset_seconds,
            remaining_requests: remaining
          )

          {:error, :error_limited, headers}

        {:ok, %{status: status}} ->
          {:error, "Unexpected status: #{status}"}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        @logger.error(Exception.message(e))

        {:error, "Request failed"}
    end
  end

  defp post_esi(url, opts) do
    try do
      req_opts =
        (opts |> with_user_agent_opts() |> Keyword.merge(@retry_opts)) ++
          [params: opts[:params] || []]

      Req.new(
        [base_url: @base_url, finch: WandererApp.Finch] ++
          req_opts
      )
      |> Req.post(url: url)
      |> case do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          {:ok, body}

        {:ok, %{status: 504}} ->
          {:error, :timeout}

        {:ok, %{status: 403}} ->
          {:error, :forbidden}

        {:ok, %{status: 420, headers: headers} = _error} ->
          # Extract rate limit information from headers
          reset_seconds = Map.get(headers, "x-esi-error-limit-reset", ["unknown"]) |> List.first()
          remaining = Map.get(headers, "x-esi-error-limit-remain", ["unknown"]) |> List.first()

          # Emit telemetry for rate limiting
          :telemetry.execute(
            [:wanderer_app, :esi, :rate_limited],
            %{
              count: 1,
              reset_duration:
                case Integer.parse(reset_seconds || "0") do
                  {seconds, _} -> seconds * 1000
                  _ -> 0
                end
            },
            %{
              method: "POST_ESI",
              path: url,
              reset_seconds: reset_seconds,
              remaining_requests: remaining
            }
          )

          Logger.warning("ESI_RATE_LIMITED: POST ESI request rate limited",
            method: "POST_ESI",
            path: url,
            reset_seconds: reset_seconds,
            remaining_requests: remaining
          )

          {:error, :error_limited, headers}

        {:ok, %{status: status}} ->
          {:error, "Unexpected status: #{status}"}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        @logger.error(Exception.message(e))

        {:error, "Request failed"}
    end
  end

  defp get_retry(path, api_opts, opts, status \\ :forbidden) do
    refresh_token? = opts |> Keyword.get(:refresh_token?, false)
    retry_count = opts |> Keyword.get(:retry_count, 0)
    character_id = opts |> Keyword.get(:character_id, nil)

    if not refresh_token? or is_nil(character_id) or retry_count >= @api_retry_count do
      {:error, status}
    else
      case refresh_token(character_id) do
        {:ok, token} ->
          auth_opts = [access_token: token.access_token] |> get_auth_opts()

          get(
            path,
            api_opts |> Keyword.merge(auth_opts),
            opts |> Keyword.merge(retry_count: retry_count + 1)
          )

        {:error, _error} ->
          {:error, status}
      end
    end
  end

  defp refresh_token(character_id) do
    {:ok,
     %{
       expires_at: expires_at,
       refresh_token: refresh_token,
       scopes: scopes,
       tracking_pool: tracking_pool
     } = character} =
      WandererApp.Character.get_character(character_id)

    refresh_token_result =
      WandererApp.Ueberauth.Strategy.Eve.OAuth.get_refresh_token([],
        with_wallet: WandererApp.Character.can_track_wallet?(character),
        is_admin?: WandererApp.Character.can_track_corp_wallet?(character),
        tracking_pool: tracking_pool,
        token: %OAuth2.AccessToken{refresh_token: refresh_token}
      )

    handle_refresh_token_result(refresh_token_result, character, character_id, expires_at, scopes)
  end

  defp handle_refresh_token_result(
         {:ok, %OAuth2.AccessToken{} = token},
         character,
         character_id,
         expires_at,
         scopes
       ) do
    # Log token refresh success with timing info
    expires_at_datetime = DateTime.from_unix!(expires_at)
    time_since_expiry = DateTime.diff(DateTime.utc_now(), expires_at_datetime, :second)

    Logger.debug(
      fn ->
        "TOKEN_REFRESH_SUCCESS: Character token refreshed successfully"
      end,
      character_id: character_id,
      time_since_expiry_seconds: time_since_expiry,
      new_expires_at: token.expires_at
    )

    {:ok, _character} =
      character
      |> WandererApp.Api.Character.update(%{
        access_token: token.access_token,
        expires_at: token.expires_at,
        scopes: scopes
      })

    WandererApp.Character.update_character(character_id, %{
      access_token: token.access_token,
      expires_at: token.expires_at
    })

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character_id}",
      :token_updated
    )

    {:ok, token}
  end

  defp handle_refresh_token_result(
         {:error, {"invalid_grant", error_message}},
         character,
         character_id,
         expires_at,
         scopes
       ) do
    expires_at_datetime = DateTime.from_unix!(expires_at)
    time_since_expiry = DateTime.diff(DateTime.utc_now(), expires_at_datetime, :second)

    Logger.warning("TOKEN_REFRESH_FAILED: Invalid grant error during token refresh",
      character_id: character_id,
      error_message: error_message,
      time_since_expiry_seconds: time_since_expiry,
      original_expires_at: expires_at
    )

    # Emit telemetry for token refresh failures
    :telemetry.execute([:wanderer_app, :token, :refresh_failed], %{count: 1}, %{
      character_id: character_id,
      error_type: "invalid_grant",
      time_since_expiry: time_since_expiry
    })

    invalidate_character_tokens(character, character_id, expires_at, scopes)
    {:error, :invalid_grant}
  end

  defp handle_refresh_token_result(
         {:error, %OAuth2.Error{reason: :econnrefused} = error},
         character,
         character_id,
         expires_at,
         scopes
       ) do
    expires_at_datetime = DateTime.from_unix!(expires_at)
    time_since_expiry = DateTime.diff(DateTime.utc_now(), expires_at_datetime, :second)

    Logger.warning("TOKEN_REFRESH_FAILED: Connection refused during token refresh",
      character_id: character_id,
      error: inspect(error),
      time_since_expiry_seconds: time_since_expiry,
      original_expires_at: expires_at
    )

    # Emit telemetry for connection failures
    :telemetry.execute([:wanderer_app, :token, :refresh_failed], %{count: 1}, %{
      character_id: character_id,
      error_type: "connection_refused",
      time_since_expiry: time_since_expiry
    })

    {:error, :econnrefused}
  end

  defp handle_refresh_token_result(
         {:error, %OAuth2.Error{} = error},
         character,
         character_id,
         expires_at,
         scopes
       ) do
    invalidate_character_tokens(character, character_id, expires_at, scopes)
    Logger.warning("Failed to refresh token for #{character_id}: #{inspect(error)}")
    {:error, :invalid_grant}
  end

  defp handle_refresh_token_result(error, character, character_id, expires_at, scopes) do
    Logger.warning("Failed to refresh token for #{character_id}: #{inspect(error)}")
    invalidate_character_tokens(character, character_id, expires_at, scopes)
    {:error, :failed}
  end

  defp invalidate_character_tokens(character, character_id, expires_at, scopes) do
    attrs = %{access_token: nil, refresh_token: nil, expires_at: expires_at, scopes: scopes}

    with {:ok, _} <- WandererApp.Api.Character.update(character, attrs) do
      WandererApp.Character.update_character(character_id, attrs)
      :ok
    else
      error ->
        Logger.error("Failed to clear tokens for #{character_id}: #{inspect(error)}")
    end

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character_id}",
      :character_token_invalid
    )
  end

  defp map_route_info(
         %{
           "origin" => origin,
           "destination" => destination,
           "systems" => result_systems,
           "success" => success
         } = _route_info
       ),
       do:
         map_route_info(%{
           origin: origin,
           destination: destination,
           systems: result_systems,
           success: success
         })

  defp map_route_info(
         %{origin: origin, destination: destination, systems: result_systems, success: success} =
           _route_info
       ) do
    systems =
      case result_systems do
        [] ->
          []

        _ ->
          result_systems |> Enum.reject(fn system_id -> system_id == origin end)
      end

    %{
      has_connection: result_systems != [],
      systems: systems,
      origin: origin,
      destination: destination,
      success: success
    }
  end

  defp map_route_info(_), do: nil
end
