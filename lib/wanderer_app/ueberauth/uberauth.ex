defmodule WandererApp.Ueberauth do
  @moduledoc false

  def client_id(opts \\ []) do
    config = _get_config()

    cond do
      Keyword.get(opts, :is_admin?) -> config[:client_id_with_corp_wallet]
      Keyword.get(opts, :with_wallet) -> config[:client_id_with_wallet]
      true -> config[:client_id_default]
    end
  end

  def client_secret(opts \\ []) do
    config = _get_config()

    cond do
      Keyword.get(opts, :is_admin?) -> config[:client_secret_with_corp_wallet]
      Keyword.get(opts, :with_wallet) -> config[:client_secret_with_wallet]
      true -> config[:client_secret_default]
    end
  end

  defp _get_config() do
    Application.get_env(:ueberauth, WandererApp.Ueberauth.Strategy.Eve.OAuth, [])
  end
end
