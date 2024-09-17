defmodule WandererApp.User do
  @moduledoc false

  require Logger

  def load(nil), do: nil

  def load(user_id) do
    case WandererApp.Api.User.by_id(user_id) do
      {:ok, user} -> user |> Ash.load!([:balance])
      {:error, _} -> nil
    end
  end

  def get_balance(nil), do: {:ok, 0.0}

  def get_balance(user), do: {:ok, user.balance || 0.0}
end
