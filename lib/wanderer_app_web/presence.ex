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

    # Delegate all cache operations to the PresenceGracePeriodManager
    WandererAppWeb.PresenceGracePeriodManager.process_presence_change(map_id, presence_data)

    {:ok, state}
  end
end
