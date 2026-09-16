defmodule WandererAppWeb.Plugs.RequirePermission do
  @moduledoc """
  Gates a controller action on a specific permission bit, checked against
  `conn.assigns[:permission_mask]` (set by `WandererAppWeb.Plugs.CheckMapApiKey`
  for both the static-key and eve-token auth paths - see that module).

  Declared once per controller with a full action -> permission map, e.g.:

      plug WandererAppWeb.Plugs.RequirePermission, %{
        index: :view_system, show: :view_system,
        create: :add_system,
        update: :update_system,
        delete: :delete_system
      }

  This has to be a controller-level `plug`, not a router `pipe_through` plug:
  `conn.private[:phoenix_action]` (what `Phoenix.Controller.action_name/1`
  reads) is only set once the router dispatches to the controller module's
  generated `call/2` - i.e. after all `pipe_through` plugs have already run -
  so only a controller-level plug can know which action is being invoked and
  therefore which bit applies.

  Actions not present in the map are passed through unchanged.
  """

  @behaviour Plug

  import Plug.Conn
  alias WandererApp.Permissions
  alias WandererAppWeb.Schemas.ResponseSchemas, as: R

  @impl true
  def init(action_permissions) when is_map(action_permissions), do: action_permissions

  @impl true
  def call(conn, action_permissions) do
    case Map.fetch(action_permissions, Phoenix.Controller.action_name(conn)) do
      {:ok, permission} -> check(conn, permission)
      :error -> conn
    end
  end

  defp check(conn, permission) do
    mask = conn.assigns[:permission_mask] || 0

    if Permissions.check_permission(mask, Permissions.bit(permission)) do
      conn
    else
      {_desc, content_type, _schema} = R.forbidden("Insufficient permissions")

      conn
      |> put_resp_content_type(content_type)
      |> send_resp(403, Jason.encode!(%{error: "Insufficient permissions"}))
      |> halt()
    end
  end
end
