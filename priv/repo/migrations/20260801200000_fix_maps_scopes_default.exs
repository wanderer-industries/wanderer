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

  # Character codes of the literal string "{wormholes}", which is what the
  # charlist default expanded to.
  @bad_default ~w(123 119 111 114 109 104 111 108 101 115 125)

  def up do
    alter table(:maps_v1) do
      modify :scopes, {:array, :text}, default: ["wormholes"]
    end

    execute(
      "UPDATE maps_v1 SET scopes = ARRAY['wormholes']::text[] WHERE scopes = ARRAY[#{Enum.map_join(@bad_default, ",", &"'#{&1}'")}]::text[]"
    )
  end

  def down do
    alter table(:maps_v1) do
      modify :scopes, {:array, :text}, default: nil
    end
  end
end
