defmodule WandererApp.Map.ConnectionLifetime do
  @moduledoc false

  @drifter_wormhole_types ["B735", "C414", "R259", "S877", "V928"]
  @drifter_lifetime_seconds 16 * 60 * 60

  @connection_time_status_default 0
  @connection_time_status_eol_4_5 3
  @connection_time_status_eol_16 4
  @connection_time_status_eol_24 5

  @frigate_ship_size 0

  @spec drifter_wormhole_type?(String.t() | nil) :: boolean()
  def drifter_wormhole_type?(wormhole_type) when is_binary(wormhole_type),
    do: String.upcase(wormhole_type) in @drifter_wormhole_types

  def drifter_wormhole_type?(_wormhole_type), do: false

  @spec initial_time_status(integer() | nil, integer() | nil, integer(), String.t() | nil) ::
          integer()
  def initial_time_status(
        _source_class,
        _target_class,
        @frigate_ship_size,
        _wormhole_type
      ),
    do: @connection_time_status_eol_4_5

  def initial_time_status(source_class, target_class, _ship_size_type, wormhole_type) do
    cond do
      drifter_wormhole_type?(wormhole_type) ->
        @connection_time_status_eol_16

      source_class in 1..4 or target_class in 1..4 ->
        @connection_time_status_eol_16

      source_class in 5..6 or target_class in 5..6 ->
        @connection_time_status_eol_24

      true ->
        @connection_time_status_default
    end
  end

  @spec drifter_wormhole_expired?(String.t() | nil, DateTime.t() | nil) :: boolean()
  def drifter_wormhole_expired?(wormhole_type, inserted_at),
    do:
      drifter_wormhole_expired?(
        wormhole_type,
        inserted_at,
        DateTime.utc_now()
      )

  @spec drifter_wormhole_expired?(String.t() | nil, DateTime.t() | nil, DateTime.t()) ::
          boolean()
  def drifter_wormhole_expired?(
        wormhole_type,
        %DateTime{} = inserted_at,
        %DateTime{} = now
      ) do
    drifter_wormhole_type?(wormhole_type) and
      DateTime.diff(now, inserted_at, :second) >= @drifter_lifetime_seconds
  end

  def drifter_wormhole_expired?(_wormhole_type, _inserted_at, _now),
    do: false
end
