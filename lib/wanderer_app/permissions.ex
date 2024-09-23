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

  @viewer_role [@view_system, @view_character, @view_connection]
  @member_role @viewer_role ++
                 [
                   @add_system,
                   @add_connection,
                   @update_system,
                   @track_character,
                   @delete_connection,
                   @delete_system,
                   @lock_system
                 ]
  @manager_role @member_role
  @admin_role @manager_role ++ [@add_acl, @delete_acl, @delete_map]

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
end
