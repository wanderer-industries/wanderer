defmodule WandererApp.Repo.Migrations.FixMapsScopesDefault do
  @moduledoc """
  Repairs the `maps_v1.scopes` column default.

  Migrations 20260331192521 and 20260406213852 declared the default as
  `default: '{wormholes}'`. In Elixir a single-quoted literal is a charlist,
  i.e. `[123, 119, 111, ...]`, so Ecto emitted an eleven-element text array of
  the character codes of the literal string `{wormholes}` instead of the
  one-element array `{wormholes}`.

  Any row inserted without an explicit `scopes` value therefore received
  garbage that cannot be cast back to `{:array, :atom}`, and every subsequent
  read of that row failed with `Ash.Error.Unknown` ("cannot load ... as type").

  This migration sets the correct default and repairs rows already written with
  the bad value.
  """

  use Ecto.Migration

  # Derived from the offending literal rather than transcribed by hand: a typo
  # in a hardcoded list would make the WHERE clause match nothing and silently
  # repair no rows. Both 20260331192521 and 20260406213852 used exactly this
  # literal, so this single value catches rows written by either.
  @bad_default Enum.map(~c"{wormholes}", &Integer.to_string/1)

  def up do
    alter table(:maps_v1) do
      modify :scopes, {:array, :text}, default: ["wormholes"]
    end

    execute(
      "UPDATE maps_v1 SET scopes = ARRAY['wormholes']::text[] WHERE scopes = ARRAY[#{Enum.map_join(@bad_default, ",", &"'#{&1}'")}]::text[]"
    )
  end

  # Deliberately not a mirror image of up/0. Restoring the original charlist
  # default would reintroduce the bug, so this drops the default instead, and
  # rows already repaired stay repaired. Rolling back therefore leaves the
  # schema in a different -- but correct -- state rather than the prior one.
  def down do
    alter table(:maps_v1) do
      modify :scopes, {:array, :text}, default: nil
    end
  end
end
