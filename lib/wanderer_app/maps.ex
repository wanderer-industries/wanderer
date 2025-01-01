defmodule WandererApp.Maps do
  @moduledoc false
  use Nebulex.Caching

  require Ash.Query

  @minimum_route_attrs [
    :system_class,
    :class_title,
    :security,
    :triglavian_invasion_status,
    :solar_system_id,
    :solar_system_name,
    :region_name,
    :is_shattered
  ]

  def find_routes(map_id, hubs, origin, routes_settings) do
    {:ok, routes} =
      WandererApp.Esi.find_routes(
        map_id,
        origin,
        hubs,
        routes_settings
      )

    systems_static_data =
      routes
      |> Enum.map(fn route_info -> route_info.systems end)
      |> List.flatten()
      |> Enum.uniq()
      |> Task.async_stream(
        fn system_id ->
          case WandererApp.CachedInfo.get_system_static_info(system_id) do
            {:ok, nil} ->
              nil

            {:ok, system} ->
              system |> Map.take(@minimum_route_attrs)
          end
        end,
        max_concurrency: 10
      )
      |> Enum.map(fn {:ok, val} -> val end)

    {:ok, %{routes: routes, systems_static_data: systems_static_data}}
  end

  def get_available_maps() do
    case WandererApp.Api.Map.available() do
      {:ok, maps} -> {:ok, maps}
      _ -> {:ok, []}
    end
  end

  def get_available_maps(current_user) do
    case WandererApp.Api.Map.available(%{}, actor: current_user) do
      {:ok, maps} -> {:ok, maps |> _filter_blocked_maps(current_user)}
      _ -> {:ok, []}
    end
  end

  def load_characters(map, character_settings, user_id) do
    {:ok, user_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: user_id})

    characters =
      map
      |> _get_map_available_characters(user_characters)
      |> Enum.map(fn c ->
        map_character(c, character_settings |> Enum.find(&(&1.character_id == c.id)))
      end)

    {:ok, %{characters: characters}}
  end

  def map_character(
        %{name: name, id: id, eve_id: eve_id, corporation_ticker: corporation_ticker} =
          _character,
        nil
      ),
      do: %{
        name: name,
        id: id,
        eve_id: eve_id,
        corporation_ticker: corporation_ticker,
        tracked: false,
        followed: false
      }

  def map_character(
        %{name: name, id: id, eve_id: eve_id, corporation_ticker: corporation_ticker} =
          _character,
        %{tracked: tracked, followed: followed} = _character_settings
      ),
      do: %{
        name: name,
        id: id,
        eve_id: eve_id,
        corporation_ticker: corporation_ticker,
        tracked: tracked,
        followed: followed
      }

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map_characters-#{_map_id}",
              opts: [ttl: :timer.seconds(5)]
            )
  defp _get_map_characters(%{id: _map_id} = map) do
    map_acls =
      map.acls
      |> Enum.map(fn acl -> acl |> Ash.load!(:members) end)

    map_acl_owner_ids =
      map_acls
      |> Enum.map(fn acl -> acl.owner_id end)

    map_members =
      map_acls
      |> Enum.map(fn acl -> acl.members end)
      |> List.flatten()
      |> Enum.filter(fn member -> member.role != :blocked end)

    map_member_eve_ids =
      map_members
      |> Enum.filter(fn member -> not is_nil(member.eve_character_id) end)
      |> Enum.map(fn member -> member.eve_character_id end)

    map_member_corporation_ids =
      map_members
      |> Enum.filter(fn member -> not is_nil(member.eve_corporation_id) end)
      |> Enum.map(fn member -> member.eve_corporation_id end)

    map_member_alliance_ids =
      map_members
      |> Enum.filter(fn member -> not is_nil(member.eve_alliance_id) end)
      |> Enum.map(fn member -> member.eve_alliance_id end)

    {:ok,
     %{
       map_acl_owner_ids: map_acl_owner_ids,
       map_member_eve_ids: map_member_eve_ids,
       map_member_corporation_ids: map_member_corporation_ids,
       map_member_alliance_ids: map_member_alliance_ids
     }}
  end

  defp _get_map_available_characters(map, user_characters) do
    {:ok,
     %{
       map_acl_owner_ids: map_acl_owner_ids,
       map_member_eve_ids: map_member_eve_ids,
       map_member_corporation_ids: map_member_corporation_ids,
       map_member_alliance_ids: map_member_alliance_ids
     }} = _get_map_characters(map)

    user_characters
    |> Enum.filter(fn c ->
      c.id == map.owner_id or
        c.id in map_acl_owner_ids or c.eve_id in map_member_eve_ids or
        to_string(c.corporation_id) in map_member_corporation_ids or
        to_string(c.alliance_id) in map_member_alliance_ids
    end)
  end

  defp _filter_blocked_maps(maps, current_user) do
    user_character_ids = current_user.characters |> Enum.map(& &1.id)
    user_character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)

    user_character_corporation_ids =
      current_user.characters
      |> Enum.map(& &1.corporation_id)
      |> Enum.map(&to_string/1)

    user_character_alliance_ids =
      current_user.characters
      |> Enum.map(& &1.alliance_id)
      |> Enum.map(&to_string/1)

    maps
    |> Enum.reduce([], fn map, acc ->
      case map.owner_id in user_character_ids do
        true ->
          [map | acc]

        false ->
          case map.acls do
            nil ->
              [map | acc]

            acls ->
              acls =
                acls
                |> Enum.map(fn acl -> acl |> Ash.load!(:members) end)

              is_blocked_any =
                acls
                |> Enum.any?(fn acl ->
                  case acl.members do
                    nil ->
                      false

                    members ->
                      members
                      |> Enum.any?(fn member ->
                        (member.role == :blocked and
                           member.eve_character_id in user_character_eve_ids) or
                          (member.role == :blocked and
                             member.eve_corporation_id in user_character_corporation_ids) or
                          (member.role == :blocked and
                             member.eve_alliance_id in user_character_alliance_ids)
                      end)
                  end
                end)

              is_allowed_character =
                acls
                |> Enum.any?(fn acl ->
                  is_owner = acl.owner_id in user_character_ids

                  is_allowed_members =
                    case acl.members do
                      nil ->
                        false

                      members ->
                        members
                        |> Enum.any?(fn member ->
                          member.role != :blocked and
                            member.eve_character_id in user_character_eve_ids
                        end)
                    end

                  is_owner or is_allowed_members
                end)

              case [is_blocked_any, is_allowed_character] do
                [_, true] ->
                  [map | acc]

                [false, false] ->
                  [map | acc]

                _ ->
                  acc
              end
          end
      end
    end)
  end

  def can_edit?(map, user) do
    user_is_owner?(user, map) or
      user_has_roles?(user, map, [:admin])
  end

  def can_view_acls?(map, user) do
    user_is_owner?(user, map) or
      user_has_roles?(user, map, [:admin, :manager])
  end

  def user_is_owner?(user, map) do
    character_ids = user.characters |> Enum.map(& &1.id)

    acl_owner_ids = map.acls |> Enum.map(& &1.owner_id)

    map.owner_id in character_ids or character_ids |> Enum.any?(fn id -> id in acl_owner_ids end)
  end

  def user_has_roles?(user, map, roles) do
    acl_roles_eve_ids =
      map.acls
      |> Enum.map(fn acl -> acl.members end)
      |> List.flatten()
      |> Enum.filter(fn member -> member.role in roles end)
      |> Enum.map(fn member -> member.eve_character_id end)

    character_eve_ids = user.characters |> Enum.map(& &1.eve_id)

    character_eve_ids |> Enum.any?(fn eve_id -> eve_id in acl_roles_eve_ids end)
  end
end
