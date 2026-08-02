defmodule WandererApp.SystemClass do
  @moduledoc """
  Canonical wormhole classification for EVE solar systems.

  Single source of truth for "is this class wormhole space", shared by the map
  server's connection scoping and by server-side kill notifications. Mirrors
  `assets/js/hooks/Mapper/components/map/helpers/isWormholeSpace.ts`.
  """

  require Logger

  @c1 1
  @c2 2
  @c3 3
  @c4 4
  @c5 5
  @c6 6
  @thera 12
  @c13 13
  @sentinel 14
  @barbican 15
  @vidette 16
  @conflux 17
  @redoubt 18

  # c1-c6, Thera, c13 shattered frigate holes, and the five drifter systems.
  @wormhole_classes [
    @c1,
    @c2,
    @c3,
    @c4,
    @c5,
    @c6,
    @c13,
    @thera,
    @sentinel,
    @barbican,
    @vidette,
    @conflux,
    @redoubt
  ]

  @doc """
  The wormhole class ids. Exposed so callers needing a compile-time list (for
  `in` checks in guards or hot paths) can derive theirs from this one rather
  than restating it.
  """
  @spec wormhole_classes() :: [pos_integer()]
  def wormhole_classes, do: @wormhole_classes

  @spec wormhole?(integer() | nil) :: boolean()
  def wormhole?(class) when class in @wormhole_classes, do: true
  def wormhole?(_), do: false

  @doc """
  Resolves a solar system id to its class and reports whether it is wormhole
  space. Returns false when static info cannot be resolved.
  """
  @spec wormhole_system?(integer()) :: boolean()
  def wormhole_system?(solar_system_id) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, %{system_class: class}} ->
        wormhole?(class)

      other ->
        Logger.warning(
          "[SystemClass] could not resolve static info for #{inspect(solar_system_id)}: #{inspect(other)}"
        )

        false
    end
  end
end
