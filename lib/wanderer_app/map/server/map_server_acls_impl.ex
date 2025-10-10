defmodule WandererApp.Map.Server.AclsImpl do
  @moduledoc false

  require Logger

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  def handle_map_acl_updated(%{map_id: map_id, map: old_map} = state, added_acls, removed_acls) do
    {:ok, map} =
      WandererApp.MapRepo.get(map_id,
        acls: [
          :owner_id,
          members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
        ]
      )

    track_acls(added_acls)

    result =
      (added_acls ++ removed_acls)
      |> Task.async_stream(
        fn acl_id ->
          update_acl(acl_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        timeout: :timer.seconds(15)
      )
      |> Enum.reduce(
        %{
          eve_alliance_ids: [],
          eve_character_ids: [],
          eve_corporation_ids: []
        },
        fn result, acc ->
          case result do
            {:ok, val} ->
              {:ok,
               %{
                 eve_alliance_ids: eve_alliance_ids,
                 eve_character_ids: eve_character_ids,
                 eve_corporation_ids: eve_corporation_ids
               }} = val

              %{
                acc
                | eve_alliance_ids: eve_alliance_ids ++ acc.eve_alliance_ids,
                  eve_character_ids: eve_character_ids ++ acc.eve_character_ids,
                  eve_corporation_ids: eve_corporation_ids ++ acc.eve_corporation_ids
              }

            error ->
              Logger.error("Failed to update map #{map_id} acl: #{inspect(error, pretty: true)}")

              acc
          end
        end
      )

    map_update = %{acls: map.acls, scope: map.scope}

    WandererApp.Map.update_map(map_id, map_update)
    WandererApp.Cache.delete("map_characters-#{map_id}")

    broadcast_acl_updates({:ok, result}, map_id)

    %{state | map: Map.merge(old_map, map_update)}
  end

  def handle_acl_updated(map_id, acl_id) do
    {:ok, %{acls: acls}} =
      WandererApp.MapRepo.get(map_id,
        acls: [
          :owner_id,
          members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
        ]
      )

    if acls |> Enum.map(& &1.id) |> Enum.member?(acl_id) do
      WandererApp.Map.update_map(map_id, %{acls: acls})
      WandererApp.Cache.delete("map_characters-#{map_id}")

      :ok =
        acl_id
        |> update_acl()
        |> broadcast_acl_updates(map_id)
    end
  end

  def handle_acl_deleted(map_id, _acl_id) do
    {:ok, %{acls: acls}} =
      WandererApp.MapRepo.get(map_id,
        acls: [
          :owner_id,
          members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
        ]
      )

    WandererApp.Map.update_map(map_id, %{acls: acls})
    WandererApp.Cache.delete("map_characters-#{map_id}")

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)
  end

  def track_acls([]), do: :ok

  def track_acls([acl_id | rest]) do
    track_acl(acl_id)
    track_acls(rest)
  end

  defp track_acl(acl_id),
    do: @pubsub_client.subscribe(WandererApp.PubSub, "acls:#{acl_id}")

  defp broadcast_acl_updates(
         {:ok,
          %{
            eve_character_ids: eve_character_ids,
            eve_corporation_ids: eve_corporation_ids,
            eve_alliance_ids: eve_alliance_ids
          }},
         map_id
       ) do
    eve_character_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_character_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "character:#{eve_character_id}",
        :update_permissions
      )
    end)

    eve_corporation_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_corporation_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "corporation:#{eve_corporation_id}",
        :update_permissions
      )
    end)

    eve_alliance_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_alliance_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "alliance:#{eve_alliance_id}",
        :update_permissions
      )
    end)

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

    :ok
  end

  defp broadcast_acl_updates(_, _map_id), do: :ok

  defp update_acl(acl_id) do
    {:ok, %{owner: owner, members: members}} =
      WandererApp.AccessListRepo.get(acl_id, [:owner, :members])

    result =
      members
      |> Enum.reduce(
        %{eve_character_ids: [owner.eve_id], eve_corporation_ids: [], eve_alliance_ids: []},
        fn member, acc ->
          case member do
            %{eve_character_id: eve_character_id} when not is_nil(eve_character_id) ->
              acc
              |> Map.put(:eve_character_ids, [eve_character_id | acc.eve_character_ids])

            %{eve_corporation_id: eve_corporation_id} when not is_nil(eve_corporation_id) ->
              acc
              |> Map.put(:eve_corporation_ids, [eve_corporation_id | acc.eve_corporation_ids])

            %{eve_alliance_id: eve_alliance_id} when not is_nil(eve_alliance_id) ->
              acc
              |> Map.put(:eve_alliance_ids, [eve_alliance_id | acc.eve_alliance_ids])

            _ ->
              acc
          end
        end
      )

    {:ok, result}
  end
end
