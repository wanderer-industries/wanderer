defmodule WandererAppWeb.Presence do
  @moduledoc false

  use Phoenix.Presence, otp_app: :wanderer_app, pubsub_server: WandererApp.PubSub

  def init(_opts), do: {:ok, %{}}

  def fetch(_topic, presences) do
    presences
  end

  def handle_metas(map_id, %{joins: _joins, leaves: _leaves}, presences, state) do
    presence_character_ids =
      presences
      |> Enum.map(fn {character_id, _} -> character_id end)

    WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)
    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", presence_character_ids)

    {:ok, state}
  end

  def presence_character_ids(map_id) do
    map_id
    |> list()
    |> Enum.map(fn {character_id, _} -> character_id end)
  end
end
