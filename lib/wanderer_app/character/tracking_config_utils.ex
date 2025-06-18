defmodule WandererApp.Character.TrackingConfigUtils do
  use Nebulex.Caching
  @moduledoc false

  @ttl :timer.minutes(5)
  @last_active_character_minutes -1 * 60 * 24 * 7

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "tracker-stats",
              opts: [ttl: @ttl]
            )
  def load_tracker_stats() do
    {:ok, characters} = get_active_characters()

    admins_count =
      characters |> Enum.filter(&WandererApp.Character.can_track_corp_wallet?/1) |> Enum.count()

    with_wallets_count =
      characters
      |> Enum.filter(
        &(WandererApp.Character.can_track_wallet?(&1) and
            not WandererApp.Character.can_track_corp_wallet?(&1))
      )
      |> Enum.count()

    default_count =
      characters
      |> Enum.filter(
        &(is_nil(&1.tracking_pool) and not WandererApp.Character.can_track_wallet?(&1) and
            not WandererApp.Character.can_track_corp_wallet?(&1))
      )
      |> Enum.count()

    result = [
      %{id: "admins", title: "Admins", value: admins_count},
      %{id: "wallet", title: "With Wallet", value: with_wallets_count},
      %{id: "default", title: "Default", value: default_count}
    ]

    {:ok, pools_count} =
      Cachex.get(
        :esi_auth_cache,
        "configs_total_count"
      )

    {:ok, pools} = get_pools_info(characters)

    {:ok, result ++ pools}
  end

  def update_active_tracking_pool() do
    {:ok, pools_count} =
      Cachex.get(
        :esi_auth_cache,
        "configs_total_count"
      )

    active_pool =
      if not is_nil(pools_count) && pools_count != 0 do
        tracking_pool_max_size = WandererApp.Env.tracking_pool_max_size()
        {:ok, characters} = get_active_characters()
        {:ok, pools} = get_pools_info(characters)

        minimal_pool_id =
          pools
          |> Enum.filter(&(&1.value < tracking_pool_max_size))
          |> Enum.min_by(& &1.value)
          |> Map.get(:id)

        if not is_nil(minimal_pool_id) do
          minimal_pool_id
        else
          "default"
        end
      else
        "default"
      end

    Cachex.put(
      :esi_auth_cache,
      "active_pool",
      active_pool
    )
  end

  def get_active_pool!() do
    Cachex.get(
      :esi_auth_cache,
      "active_pool"
    )
    |> case do
      {:ok, active_pool} when not is_nil(active_pool) ->
        active_pool

      _ ->
        "default"
    end
  end

  defp get_active_characters() do
    WandererApp.Api.Character.last_active(%{
      from:
        DateTime.utc_now()
        |> DateTime.add(@last_active_character_minutes, :minute)
    })
  end

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "character-pools-info",
              opts: [ttl: @ttl]
            )
  defp get_pools_info(characters) do
    {:ok, pools_count} =
      Cachex.get(
        :esi_auth_cache,
        "configs_total_count"
      )

    if not is_nil(pools_count) && pools_count != 0 do
      pools =
        1..pools_count
        |> Enum.map(fn pool_id ->
          pools_character_count =
            characters
            |> Enum.filter(
              &(&1.tracking_pool == "#{pool_id}" and
                  not WandererApp.Character.can_track_wallet?(&1) and
                  not WandererApp.Character.can_track_corp_wallet?(&1))
            )
            |> Enum.count()

          %{id: "#{pool_id}", title: "Pool #{pool_id}", value: pools_character_count}
        end)

      {:ok, pools}
    else
      {:ok, []}
    end
  end
end
