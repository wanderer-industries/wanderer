defmodule WandererApp.Api.Calculations.CalcMapPermissions do
  @moduledoc false

  use Ash.Resource.Calculation
  require Ash.Query

  import Bitwise

  @impl true
  def load(_query, _opts, _context) do
    [
      acls: [
        :owner_id,
        members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
      ]
    ]
  end

  @impl true
  def calculate([record], _opts, %{actor: actor}) do
    characters = actor.characters

    character_ids = characters |> Enum.map(& &1.id)
    character_eve_ids = characters |> Enum.map(& &1.eve_id)

    character_corporation_ids =
      characters |> Enum.map(& &1.corporation_id) |> Enum.map(&to_string/1)

    character_alliance_ids = characters |> Enum.map(& &1.alliance_id) |> Enum.map(&to_string/1)

    result =
      record.acls
      |> Enum.filter(fn acl ->
        acl.owner_id in character_ids or
          acl.members |> Enum.any?(fn member -> member.eve_character_id in character_eve_ids end) or
          acl.members
          |> Enum.any?(fn member -> member.eve_corporation_id in character_corporation_ids end) or
          acl.members
          |> Enum.any?(fn member -> member.eve_alliance_id in character_alliance_ids end)
      end)
      |> Enum.reduce([0, 0], fn acl, acc ->
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
                  _ -> WandererApp.Permissions.calc_role_mask(member.role, acc)
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
                member.eve_character_id in character_eve_ids or
                  member.eve_corporation_id in character_corporation_ids or
                  member.eve_alliance_id in character_alliance_ids
              end)
              |> Enum.reduce(0, fn member, acc ->
                case acc do
                  -1 -> -1
                  _ -> WandererApp.Permissions.calc_role_mask(member.role, acc)
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
                  _ -> WandererApp.Permissions.calc_role_mask(member.role, acc)
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

  @impl true
  def calculate(_records, _opts, _context) do
    [0]
  end
end
