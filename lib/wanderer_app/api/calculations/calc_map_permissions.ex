defmodule WandererApp.Api.Calculations.CalcMapPermissions do
  @moduledoc false

  use Ash.Resource.Calculation
  require Ash.Query

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
  def calculate([record], _opts, %{actor: actor}),
    do: WandererApp.Permissions.check_characters_access(actor.characters, record.acls)

  @impl true
  def calculate(_records, _opts, _context) do
    [0]
  end
end
