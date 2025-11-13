defmodule WandererApp.Api.Changes.InjectMapFromActor do
  @moduledoc """
  Automatically injects map_id from the authenticated map.

  The Bearer token identifies the map, so we use that instead of
  requiring the client to provide map_id in the request.

  This change:
  1. Gets the map from conn.assigns.map (set by auth plug)
  2. Sets map_id attribute to that map's ID
  3. Ignores any map_id provided by the client (for simplicity)

  ## Usage

  In an Ash resource action:

      create :create do
        accept [:solar_system_id, :name, :position_x, :position_y]
        change InjectMapFromActor
      end
  """

  use Ash.Resource.Change
  require Logger

  alias WandererApp.Api.ActorWithMap

  @telemetry_prefix [:wanderer_app, :inject_map_from_actor]

  @impl true
  def change(changeset, _opts, _context) do
    map = get_map_from_changeset(changeset)

    client_provided_map_id =
      Ash.Changeset.get_argument(changeset, :map_id) ||
        Ash.Changeset.get_attribute(changeset, :map_id)

    if client_provided_map_id do
      :telemetry.execute(
        [:wanderer_app, :api, :deprecated],
        %{count: 1},
        %{
          deprecation: "map_id_in_request",
          message: "Clients should not provide map_id - it's determined from token"
        }
      )
    end

    case map do
      %{id: map_id} when is_binary(map_id) ->
        Ash.Changeset.force_change_attribute(changeset, :map_id, map_id)

      nil ->
        actor = get_in(changeset.context, [:private, :actor])

        user_id =
          case actor do
            %ActorWithMap{user: %{id: id}} -> id
            %{id: id} -> id
            _ -> nil
          end

        actor_type = get_actor_type(actor)
        actor_keys = get_actor_keys(actor)
        context_keys = Map.keys(changeset.context)
        private_keys = Map.keys(changeset.context[:private] || %{})

        Logger.error("""
        [InjectMapFromActor] No map in context despite passing authentication
          user_id: #{inspect(user_id)}
          actor_type: #{inspect(actor_type)}
          actor_keys: #{inspect(actor_keys)}
          actor: #{inspect(actor)}
          context_keys: #{inspect(context_keys)}
          private_keys: #{inspect(private_keys)}
          changeset_action: #{changeset.action.name}
        """)

        :telemetry.execute(
          @telemetry_prefix ++ [:missing_map],
          %{count: 1},
          %{user_id: user_id, action: changeset.action.name}
        )

        # This is a server-side bug, not a client auth issue
        Ash.Changeset.add_error(changeset,
          field: :base,
          message: "Internal server error: missing map context. Please contact support."
        )

      other ->
        Logger.error(
          "[InjectMapFromActor] Unexpected map value in context",
          map_value: inspect(other),
          map_type: get_struct_type(other),
          context_keys: Map.keys(changeset.context)
        )

        :telemetry.execute(
          @telemetry_prefix ++ [:invalid_map],
          %{count: 1},
          %{map_type: get_struct_type(other)}
        )

        Ash.Changeset.add_error(changeset,
          field: :base,
          message: "Internal server error: invalid map context. Please contact support."
        )
    end
  end

  defp get_map_from_changeset(changeset) do
    actor = get_in(changeset.context, [:private, :actor])

    case actor do
      %ActorWithMap{map: map} when not is_nil(map) ->
        map

      _ ->
        changeset.context[:map]
    end
  end

  defp get_actor_type(%_{} = actor), do: actor.__struct__
  defp get_actor_type(_), do: :not_a_struct

  defp get_actor_keys(actor) when is_map(actor), do: Map.keys(actor)
  defp get_actor_keys(_), do: nil

  defp get_struct_type(%_{} = struct), do: struct.__struct__
  defp get_struct_type(_), do: :not_a_struct
end
