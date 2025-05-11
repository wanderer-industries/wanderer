defmodule WandererAppWeb.Presence do
  @moduledoc false

  use Phoenix.Presence, otp_app: :wanderer_app, pubsub_server: WandererApp.PubSub

  def init(_opts), do: {:ok, %{}}

  def fetch(_topic, presences) do
    presences
  end

  def handle_metas(map_id, %{joins: _joins, leaves: _leaves}, presences, state) do
    presence_data =
      presences
      |> Enum.map(fn {character_id, meta} ->
        from =
          meta
          |> Enum.map(& &1.from)
          |> Enum.sort(&(DateTime.compare(&1, &2) != :gt))
          |> List.first()

        any_tracked = Enum.any?(meta, fn %{tracked: tracked} -> tracked end)

        %{character_id: character_id, tracked: any_tracked, from: from}
      end)

    presence_tracked_character_ids =
      presence_data
      |> Enum.filter(fn %{tracked: tracked} -> tracked end)
      |> Enum.map(fn %{character_id: character_id} ->
        character_id
      end)

    WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)

    WandererApp.Cache.insert(
      "map_#{map_id}:presence_character_ids",
      presence_tracked_character_ids
    )

    WandererApp.Cache.insert(
      "map_#{map_id}:presence_data",
      presence_data
    )

    {:ok, state}
  end
end
