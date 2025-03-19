defmodule WandererApp.Vault do
  use Cloak.Vault, otp_app: :wanderer_app

  @impl GenServer
  def init(config) do
    cipher_key = decode_env!("CLOAK_KEY")

    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: cipher_key,
          iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    key = System.get_env(var)
    if is_nil(key),
      do: raise("No environment variable found for #{var}"),
      else: Base.decode64!(key)
  end
end
