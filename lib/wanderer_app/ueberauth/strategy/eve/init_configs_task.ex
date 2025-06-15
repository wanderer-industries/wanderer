defmodule WandererApp.Esi.InitClientsTask do
  use Task

  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    Logger.info("starting")

    cache_clients()
    WandererApp.Character.TrackingConfigUtils.update_active_tracking_pool()
  end

  defp cache_clients() do
    config = Application.get_env(:ueberauth, WandererApp.Ueberauth.Strategy.Eve.OAuth, [])

    cache_client("default", %{
      client_id: config[:client_id_default],
      client_secret: config[:client_secret_default]
    })

    Enum.each(1..10, fn index ->
      client_id = config["client_id_#{index}" |> String.to_atom()]
      client_secret = config["client_secret_#{index}" |> String.to_atom()]

      if client_id != "" && client_secret != "" do
        cache_client(index, %{
          client_id: client_id,
          client_secret: client_secret
        })
      end
    end)
  end

  defp cache_client(id, config) do
    config_uuid = UUID.uuid4()

    config =
      config
      |> Map.merge(%{
        id: id,
        uuid: config_uuid
      })

    Cachex.put(
      :esi_auth_cache,
      "config_#{id}",
      config
    )

    Cachex.put(
      :esi_auth_cache,
      config_uuid,
      config
    )

    # Cachex.put(
    #   :esi_auth_cache,
    #   "config_uuid_#{id}",
    #   config_uuid
    # )

    configs_total_count =
      if id == "default" do
        0
      else
        id
      end

    Cachex.put(
      :esi_auth_cache,
      "configs_total_count",
      configs_total_count
    )
  end
end
