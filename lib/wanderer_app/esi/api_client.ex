defmodule WandererApp.Esi.ApiClient do
  use Nebulex.Caching
  @moduledoc false

  require Logger
  alias WandererApp.Cache

  @ttl :timer.hours(1)
  @routes_ttl :timer.minutes(15)

  @base_url "https://esi.evetech.net/latest"

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

  @cache_opts [cache: true]
  @retry_opts [retry: false, retry_log_level: :warning]
  @timeout_opts [receive_timeout: :timer.seconds(30)]
  @api_retry_count 1

  @logger Application.compile_env(:wanderer_app, :logger)

  def get_server_status, do: get("/status")

  def set_autopilot_waypoint(add_to_beginning, clear_other_waypoints, destination_id, opts \\ []),
    do:
      post_esi(
        "/ui/autopilot/waypoint",
        opts
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
        post(
          "#{@base_url}/characters/affiliation/",
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

          chains = _remove_intersection([map_chains | thera_chains] |> List.flatten())

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

    avoidance_list = [routes_settings.avoid | avoidance_list] |> List.flatten() |> Enum.uniq()

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
            @logger.error("Error getting custom routes for #{inspect(origin)}: #{inspect(hubs)}")

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
         max_concurrency: 20,
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

      {:error, :not_found} ->
        %{"origin" => origin, "destination" => destination, "systems" => [], "success" => false}

      {:error, error} ->
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
    case _get_alliance_info(eve_id, "", opts) do
      {:ok, result} -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "info-#{eve_id}",
              opts: [ttl: @ttl]
            )
  def get_corporation_info(eve_id, opts \\ []) do
    case _get_corporation_info(eve_id, "", opts) do
      {:ok, result} -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
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
           opts |> _with_cache_opts()
         ) do
      {:ok, result} -> {:ok, result |> Map.put("eve_id", eve_id)}
      {:error, error} -> {:error, error}
    end
  end

  @decorate cacheable(
              cache: Cache,
              key: "get_custom_route_base_url"
            )
  def get_custom_route_base_url, do: WandererApp.Env.custom_route_base_url()

  def get_character_wallet(character_eve_id, opts \\ []),
    do: _get_character_auth_data(character_eve_id, "wallet", opts)

  def get_corporation_wallets(corporation_id, opts \\ []),
    do: _get_corporation_auth_data(corporation_id, "wallets", opts)

  def get_corporation_wallet_journal(corporation_id, division, opts \\ []),
    do: _get_corporation_auth_data(corporation_id, "wallets/#{division}/journal", opts)

  def get_corporation_wallet_transactions(corporation_id, division, opts \\ []),
    do: _get_corporation_auth_data(corporation_id, "wallets/#{division}/transactions", opts)

  def get_character_location(character_eve_id, opts \\ []),
    do: _get_character_auth_data(character_eve_id, "location", opts)

  def get_character_online(character_eve_id, opts \\ []),
    do: _get_character_auth_data(character_eve_id, "online", opts)

  def get_character_ship(character_eve_id, opts \\ []),
    do: _get_character_auth_data(character_eve_id, "ship", opts)

  def search(character_eve_id, opts \\ []),
    do: _search(character_eve_id, opts[:params][:search], opts)

  @decorate cacheable(
              cache: Cache,
              key: "search-#{character_eve_id}-#{search |> Slug.slugify()}",
              opts: [ttl: @ttl]
            )
  defp _search(character_eve_id, search, opts \\ []) when is_binary(search) do
    _get_character_auth_data(
      character_eve_id,
      "search",
      opts
    )
  end

  defp _remove_intersection(pairs_arr) do
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
    do: _get_routes_eve(origin, destination, params, opts)

  defp _get_routes_eve(origin, destination, params, opts),
    do:
      get(
        "/route/#{origin}/#{destination}/?#{params |> Plug.Conn.Query.encode()}",
        opts |> _with_cache_opts()
      )

  defp _get_auth_opts(opts), do: [auth: {:bearer, opts[:access_token]}]

  defp _get_alliance_info(alliance_eve_id, info_path, opts),
    do:
      get(
        "/alliances/#{alliance_eve_id}/#{info_path}",
        opts |> _with_cache_opts()
      )

  defp _get_corporation_info(corporation_eve_id, info_path, opts),
    do:
      get(
        "/corporations/#{corporation_eve_id}/#{info_path}",
        opts |> _with_cache_opts()
      )

  defp _get_character_auth_data(character_eve_id, info_path, opts) do
    path = "/characters/#{character_eve_id}/#{info_path}"

    auth_opts =
      [params: opts[:params] || []] ++
        (opts |> _get_auth_opts() |> _with_cache_opts())

    character_id = opts |> Keyword.get(:character_id, nil)

    if not _is_access_token_expired?(character_id) do
      get(
        path,
        auth_opts,
        opts
      )
    else
      _get_retry(path, auth_opts, opts)
    end
  end

  defp _is_access_token_expired?(character_id) do
    {:ok, %{expires_at: expires_at} = _character} =
      WandererApp.Character.get_character(character_id)

    now = DateTime.utc_now() |> DateTime.to_unix()

    expires_at - now <= 0
  end

  defp _get_corporation_auth_data(corporation_eve_id, info_path, opts),
    do:
      get(
        "/corporations/#{corporation_eve_id}/#{info_path}",
        [params: opts[:params] || []] ++
          (opts |> _get_auth_opts() |> _with_cache_opts()),
        opts
      )

  defp _with_cache_opts(opts) do
    opts |> Keyword.merge(@cache_opts) |> Keyword.merge(cache_dir: System.tmp_dir!())
  end

  defp post_esi(path, opts),
    do:
      post(
        "#{@base_url}#{path}",
        [params: opts[:params] || []] ++ (opts |> _get_auth_opts())
      )

  defp get(path, api_opts \\ [], opts \\ []) do
    try do
      case Req.get("#{@base_url}#{path}", api_opts |> Keyword.merge(@retry_opts)) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: 504}} ->
          {:error, :timeout}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: 403} = _error} ->
          _get_retry(path, api_opts, opts)

        {:ok, %{status: 420} = _error} ->
          _get_retry(path, api_opts, opts)

        {:ok, %{status: status}} ->
          {:error, "Unexpected status: #{status}"}

        {:error, _reason} ->
          {:error, "Request failed"}
      end
    rescue
      e ->
        @logger.error(Exception.message(e))

        {:error, "Request failed"}
    end
  end

  defp post(url, opts) do
    try do
      case Req.post("#{url}", opts) do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          {:ok, body}

        {:ok, %{status: 504}} ->
          {:error, :timeout}

        {:ok, %{status: 403}} ->
          {:error, :forbidden}

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

  defp _get_retry(path, api_opts, opts) do
    refresh_token? = opts |> Keyword.get(:refresh_token?, false)
    retry_count = opts |> Keyword.get(:retry_count, 0)
    character_id = opts |> Keyword.get(:character_id, nil)

    if not refresh_token? or is_nil(character_id) or retry_count >= @api_retry_count do
      {:error, :forbidden}
    else
      case _refresh_token(character_id) do
        {:ok, token} ->
          auth_opts = [access_token: token.access_token] |> _get_auth_opts()

          get(
            path,
            api_opts |> Keyword.merge(auth_opts),
            opts |> Keyword.merge(retry_count: retry_count + 1)
          )

        {:error, _error} ->
          {:error, :forbidden}
      end
    end
  end

  defp _refresh_token(character_id) do
    {:ok, %{expires_at: expires_at, refresh_token: refresh_token, scopes: scopes} = character} =
      WandererApp.Character.get_character(character_id)

    case WandererApp.Ueberauth.Strategy.Eve.OAuth.get_refresh_token([],
           with_wallet: WandererApp.Character.can_track_wallet?(character),
           is_admin?: WandererApp.Character.can_track_corp_wallet?(character),
           token: %OAuth2.AccessToken{refresh_token: refresh_token}
         ) do
      {:ok, %OAuth2.AccessToken{} = token} ->
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

      {:error, {"invalid_grant", error_message}} ->
        {:ok, _character} =
          character
          |> WandererApp.Api.Character.update(%{
            access_token: nil,
            refresh_token: nil,
            expires_at: expires_at,
            scopes: scopes
          })

        WandererApp.Character.update_character(character_id, %{
          access_token: nil,
          refresh_token: nil,
          expires_at: expires_at,
          scopes: scopes
        })

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character:#{character_id}",
          :character_token_invalid
        )

        Logger.warning("Failed to refresh token for #{character_id}: #{error_message}")
        {:error, :invalid_grant}

      error ->
        Logger.warning("Failed to refresh token for #{character_id}: #{inspect(error)}")
        {:error, :failed}
    end
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
