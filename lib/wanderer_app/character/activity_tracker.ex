defmodule WandererApp.Character.ActivityTracker do
  @moduledoc false
  use GenServer

  require Logger

  @name __MODULE__

  def start_link(args) do
    GenServer.start(__MODULE__, args, name: @name)
  end

  @impl true
  def init(_args) do
    Logger.info("#{__MODULE__} started")

    {:ok, %{}, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    :telemetry.attach_many(
      "map_character_activity_handler",
      [
        [:wanderer_app, :map, :character, :jump]
      ],
      &WandererApp.Character.ActivityTracker.handle_event/4,
      nil
    )

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  def handle_event(
        [:wanderer_app, :map, :character, :jump],
        _event_data,
        %{
          character: character,
          map_id: map_id,
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        } = _metadata,
        _config
      ) do
    {:ok, _} =
      WandererApp.Api.MapChainPassages.new(%{
        map_id: map_id,
        character_id: character.id,
        ship_type_id: character.ship,
        ship_name: character.ship_name,
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id
      })
  end
end
