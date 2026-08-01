defmodule WandererApp.Kills.SystemClass do
  @moduledoc """
  Wormhole classification for EVE solar systems.

  Ported from `assets/js/hooks/Mapper/components/map/helpers/isWormholeSpace.ts`
  so the kills widget and server-side notifications agree on what counts as
  wormhole space.
  """

  require Logger

  # c1-c6, Thera (12), c13 shattered frigate holes (13),
  # drifter: Sentinel/Barbican/Vidette/Conflux/Redoubt (14-18)
  @wormhole_classes MapSet.new([1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 16, 17, 18])

  @spec wormhole?(integer() | nil) :: boolean()
  def wormhole?(nil), do: false
  def wormhole?(class) when is_integer(class), do: MapSet.member?(@wormhole_classes, class)
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
