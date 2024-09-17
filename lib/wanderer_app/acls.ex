defmodule WandererApp.Acls do
  @moduledoc false

  def get_available_acls() do
    case WandererApp.Api.AccessList.available() do
      {:ok, acls} -> {:ok, acls}
      _ -> {:ok, []}
    end
  end

  def get_available_acls(current_user) do
    case WandererApp.Api.AccessList.available(%{}, actor: current_user) do
      {:ok, acls} -> {:ok, acls |> Enum.sort_by(& &1.name, :asc)}
      _ -> {:ok, []}
    end
  end
end
