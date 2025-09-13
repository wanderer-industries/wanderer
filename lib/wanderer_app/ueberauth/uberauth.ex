defmodule WandererApp.Ueberauth do
  @moduledoc false

  def client_id(opts \\ []) do
    config = get_config()
    tracking_pool = Keyword.get(opts, :tracking_pool)

    cond do
      Keyword.get(opts, :is_admin?) -> config[:client_id_with_corp_wallet]
      Keyword.get(opts, :with_wallet) -> config[:client_id_with_wallet]
      not is_nil(tracking_pool) -> get_settings(tracking_pool)[:client_id]
      true -> config[:client_id_default]
    end
  end

  def client_secret(opts \\ []) do
    config = get_config()
    tracking_pool = Keyword.get(opts, :tracking_pool)

    cond do
      Keyword.get(opts, :is_admin?) -> config[:client_secret_with_corp_wallet]
      Keyword.get(opts, :with_wallet) -> config[:client_secret_with_wallet]
      not is_nil(tracking_pool) -> get_settings(tracking_pool)[:client_secret]
      true -> config[:client_secret_default]
    end
  end

  defp get_settings(nil) do
    {:ok, esi_config} =
      Cachex.get(
        :esi_auth_cache,
        "config_default"
      )

    esi_config
  end

  defp get_settings(tracking_pool) do
    {:ok, esi_config} =
      Cachex.get(
        :esi_auth_cache,
        "config_#{tracking_pool}"
      )

    esi_config
  end

  defp get_config() do
    Application.get_env(:ueberauth, WandererApp.Ueberauth.Strategy.Eve.OAuth, [])
  end
end
