defmodule WandererApp.Permissions do
  @moduledoc false
  import Bitwise

  @view_system 1
  @view_character 2
  @view_connection 4
  @add_system 8
  @add_connection 16
  @update_system 32
  @track_character 64
  @delete_connection 128
  @delete_system 256
  @lock_system 512
  @add_acl 1024
  @delete_acl 2048
  @delete_map 4096
  @manage_map 8192
  @admin_map 16384

  @viewer_role [@view_system, @view_character, @view_connection]
  @member_role @viewer_role ++
                 [
                   @add_system,
                   @add_connection,
                   @update_system,
                   @track_character,
                   @delete_connection,
                   @delete_system
                 ]
  @manager_role @member_role ++ [@lock_system, @manage_map]
  @admin_role @manager_role ++ [@add_acl, @delete_acl, @delete_map, @admin_map]

  @viewer_role_mask @viewer_role |> Enum.reduce(0, fn x, acc -> x ||| acc end)
  @member_role_mask @member_role |> Enum.reduce(0, fn x, acc -> x ||| acc end)
  @manager_role_mask @manager_role |> Enum.reduce(0, fn x, acc -> x ||| acc end)
  @admin_role_mask @admin_role |> Enum.reduce(0, fn x, acc -> x ||| acc end)

  def role_mask(nil), do: 0
  def role_mask(:viewer), do: @viewer_role_mask
  def role_mask(:member), do: @member_role_mask
  def role_mask(:manager), do: @manager_role_mask
  def role_mask(:admin), do: @admin_role_mask
  def role_mask(:blocked), do: 0

  def calc_roles_mask([], mask), do: mask

  def calc_roles_mask([role | rest], mask) do
    calc_roles_mask(rest, calc_role_mask(role, mask))
  end

  def calc_role_mask(:blocked, _mask), do: -1

  def calc_role_mask(role, mask) do
    mask ||| role_mask(role)
  end

  def check_permission(-1, _permission), do: false

  def check_permission(user_permissions, permission) do
    (user_permissions &&& permission) != 0
  end

  def get_map_permissions(user_permissions, owner_id, user_character_ids) do
    case owner_id in user_character_ids do
      true ->
        role_mask(:admin) |> get_permissions()

      _ ->
        get_permissions(user_permissions)
    end
  end

  def get_permissions(user_permissions) do
    %{
      admin_map: check_permission(user_permissions, @admin_map),
      manage_map: check_permission(user_permissions, @manage_map),
      view_system: check_permission(user_permissions, @view_system),
      view_character: check_permission(user_permissions, @view_character),
      view_connection: check_permission(user_permissions, @view_connection),
      add_system: check_permission(user_permissions, @add_system),
      add_connection: check_permission(user_permissions, @add_connection),
      update_system: check_permission(user_permissions, @update_system),
      track_character: check_permission(user_permissions, @track_character),
      delete_connection: check_permission(user_permissions, @delete_connection),
      delete_system: check_permission(user_permissions, @delete_system),
      lock_system: check_permission(user_permissions, @lock_system),
      add_acl: check_permission(user_permissions, @add_acl),
      delete_acl: check_permission(user_permissions, @delete_acl),
      delete_map: check_permission(user_permissions, @delete_map)
    }
  end

  def check_characters_access(characters, acls) do
    character_ids = characters |> Enum.map(& &1.id)
    character_eve_ids = characters |> Enum.map(& &1.eve_id)

    character_corporation_ids =
      characters |> Enum.map(& &1.corporation_id) |> Enum.map(&to_string/1)

    character_alliance_ids = characters |> Enum.map(& &1.alliance_id) |> Enum.map(&to_string/1)

    result =
      acls
      |> Enum.reduce([0, 0], fn acl, acc ->
        is_owner? = acl.owner_id in character_ids

        is_character_member? =
          acl.members |> Enum.any?(fn member -> member.eve_character_id in character_eve_ids end)

        is_corporation_member? =
          acl.members
          |> Enum.any?(fn member -> member.eve_corporation_id in character_corporation_ids end)

        is_alliance_member? =
          acl.members
          |> Enum.any?(fn member -> member.eve_alliance_id in character_alliance_ids end)

        if is_owner? || is_character_member? || is_corporation_member? || is_alliance_member? do
          case acc do
            [_, -1] ->
              [-1, -1]

            [-1, char_acc] ->
              char_acl_mask =
                acl.members
                |> Enum.filter(fn member ->
                  member.eve_character_id in character_eve_ids
                end)
                |> Enum.reduce(0, fn member, acc ->
                  case acc do
                    -1 -> -1
                    _ -> calc_role_mask(member.role, acc)
                  end
                end)

              char_acc =
                case char_acl_mask do
                  -1 -> -1
                  _ -> char_acc ||| char_acl_mask
                end

              [-1, char_acc]

            [any_acc, char_acc] ->
              any_acl_mask =
                acl.members
                |> Enum.filter(fn member ->
                  member.eve_character_id in character_eve_ids ||
                    member.eve_corporation_id in character_corporation_ids ||
                    member.eve_alliance_id in character_alliance_ids
                end)
                |> Enum.reduce(0, fn member, acc ->
                  case acc do
                    -1 -> -1
                    _ -> calc_role_mask(member.role, acc)
                  end
                end)

              char_acl_mask =
                acl.members
                |> Enum.filter(fn member ->
                  member.eve_character_id in character_eve_ids
                end)
                |> Enum.reduce(0, fn member, acc ->
                  case acc do
                    -1 -> -1
                    _ -> calc_role_mask(member.role, acc)
                  end
                end)

              any_acc =
                case any_acl_mask do
                  -1 -> -1
                  _ -> any_acc ||| any_acl_mask
                end

              char_acc =
                case char_acl_mask do
                  -1 -> -1
                  _ -> char_acc ||| char_acl_mask
                end

              [any_acc, char_acc]
          end
        else
          acc
        end
      end)

    case result do
      [_, -1] ->
        [-1]

      [-1, char_acc] ->
        [char_acc]

      [any_acc, _char_acc] ->
        [any_acc]
    end
  end
end
