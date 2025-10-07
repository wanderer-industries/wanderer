defmodule WandererApp.Maps do
  @moduledoc false
  use Nebulex.Caching

  require Ash.Query
  import Ecto.Query
  require Logger

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

  def find_routes(map_id, hubs, origin, routes_settings, false) do
    WandererApp.Esi.find_routes(
      map_id,
      origin,
      hubs,
      routes_settings
    )
    |> case do
      {:ok, routes} ->
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
            max_concurrency: System.schedulers_online() * 4
          )
          |> Enum.map(fn {:ok, val} -> val end)

        {:ok, %{routes: routes, systems_static_data: systems_static_data}}

      error ->
        {:ok, %{routes: [], systems_static_data: []}}
    end
  end

  def find_routes(map_id, hubs, origin, routes_settings, true) do
    origin = origin |> String.to_integer()
    hubs = hubs |> Enum.map(&(&1 |> String.to_integer()))

    routes =
      hubs
      |> Enum.map(fn hub ->
        %{origin: origin, destination: hub, success: false, systems: [], has_connection: false}
      end)

    {:ok, %{routes: routes, systems_static_data: []}}
  end

  def get_available_maps() do
    case WandererApp.Api.Map.available() do
      {:ok, maps} -> {:ok, maps}
      _ -> {:ok, []}
    end
  end

  def get_available_maps(current_user) do
    case WandererApp.Api.Map.available(%{}, actor: current_user) do
      {:ok, maps} -> {:ok, maps |> filter_blocked_maps(current_user)}
      _ -> {:ok, []}
    end
  end

  def get_tracked_map_characters(map_id, current_user) do
    case WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_filtered(
           map_id,
           current_user.characters |> Enum.map(& &1.id)
         ) do
      {:ok, settings} ->
        {:ok,
         settings
         |> Enum.map(fn s -> s |> Ash.load!(:character) |> Map.get(:character) end)}

      _ ->
        {:ok, []}
    end
  end

  def load_characters(map, user_id) when not is_nil(map) do
    {:ok, user_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: user_id})

    map_available_characters =
      map
      |> get_map_available_characters(user_characters)

    {:ok, character_settings} =
      WandererApp.MapCharacterSettingsRepo.get_by_map_filtered(
        map.id,
        map_available_characters |> Enum.map(& &1.id)
      )

    characters =
      map_available_characters
      |> Enum.map(fn c ->
        map_character(c, character_settings |> Enum.find(&(&1.character_id == c.id)))
      end)

    {:ok, %{characters: characters}}
  end

  def load_characters(_map, _user_id), do: {:ok, %{characters: []}}

  def map_character(
        %{
          name: name,
          id: id,
          eve_id: eve_id,
          access_token: access_token,
          corporation_id: corporation_id,
          alliance_id: alliance_id,
          alliance_ticker: alliance_ticker,
          corporation_ticker: corporation_ticker,
          solar_system_id: solar_system_id,
          ship: ship_type_id,
          ship_name: ship_name,
          inserted_at: inserted_at
        } =
          _character,
        nil
      ),
      do: %{
        name: name,
        id: id,
        eve_id: eve_id,
        access_token: access_token,
        corporation_id: corporation_id,
        alliance_id: alliance_id,
        alliance_ticker: alliance_ticker,
        corporation_ticker: corporation_ticker,
        solar_system_id: solar_system_id,
        ship: ship_type_id,
        ship_name: ship_name,
        inserted_at: inserted_at,
        tracked: false
      }

  def map_character(
        %{
          name: name,
          id: id,
          eve_id: eve_id,
          access_token: access_token,
          corporation_id: corporation_id,
          alliance_id: alliance_id,
          alliance_ticker: alliance_ticker,
          corporation_ticker: corporation_ticker,
          solar_system_id: solar_system_id,
          ship: ship_type_id,
          ship_name: ship_name,
          inserted_at: inserted_at
        } =
          _character,
        %{tracked: tracked} = _character_settings
      ),
      do: %{
        name: name,
        id: id,
        eve_id: eve_id,
        access_token: access_token,
        corporation_id: corporation_id,
        alliance_id: alliance_id,
        alliance_ticker: alliance_ticker,
        corporation_ticker: corporation_ticker,
        solar_system_id: solar_system_id,
        ship: ship_type_id,
        ship_name: ship_name,
        inserted_at: inserted_at,
        tracked: tracked
      }

  defp get_map_characters(%{id: map_id} = map) do
    WandererApp.Cache.lookup!("map_characters-#{map_id}")
    |> case do
      nil ->
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

        map_characters =
          %{
            map_acl_owner_ids: map_acl_owner_ids,
            map_member_eve_ids: map_member_eve_ids,
            map_member_corporation_ids: map_member_corporation_ids,
            map_member_alliance_ids: map_member_alliance_ids
          }

        WandererApp.Cache.insert(
          "map_characters-#{map_id}",
          map_characters
        )

        {:ok, map_characters}

      map_characters ->
        {:ok, map_characters}
    end
  end

  defp get_map_available_characters(map, user_characters) do
    {:ok,
     %{
       map_acl_owner_ids: map_acl_owner_ids,
       map_member_eve_ids: map_member_eve_ids,
       map_member_corporation_ids: map_member_corporation_ids,
       map_member_alliance_ids: map_member_alliance_ids
     }} = get_map_characters(map)

    user_characters
    |> Enum.filter(fn c ->
      is_owner = c.id == map.owner_id
      is_acl_owner = c.id in map_acl_owner_ids
      is_member_eve = c.eve_id in map_member_eve_ids
      is_member_corp = to_string(c.corporation_id) in map_member_corporation_ids
      is_member_alliance = to_string(c.alliance_id) in map_member_alliance_ids

      has_access =
        is_owner or is_acl_owner or is_member_eve or is_member_corp or is_member_alliance

      has_access
    end)
  end

  defp filter_blocked_maps(maps, current_user) do
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

  def get_system_comments_activity(system_id) do
    from(sc in WandererApp.Api.MapSystemComment,
      where: sc.system_id == ^system_id,
      group_by: [sc.system_id],
      select: {count(sc.system_id)}
    )
    |> WandererApp.Repo.all()
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

  def check_user_can_delete_map(map_slug, current_user) do
    map_slug
    |> WandererApp.Api.Map.get_map_by_slug()
    |> Ash.load([:owner, :acls, :user_permissions], actor: current_user)
    |> case do
      {:ok,
       %{
         user_permissions: user_permissions,
         owner_id: owner_id
       } = map} ->
        user_permissions =
          WandererApp.Permissions.get_map_permissions(
            user_permissions,
            owner_id,
            current_user.characters |> Enum.map(& &1.id)
          )

        case user_permissions.delete_map do
          true ->
            {:ok, map}

          _ ->
            {:error, :not_authorized}
        end

      error ->
        {:error, error}
    end
  end
end
