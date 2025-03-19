defmodule WandererApp.Vault do
  use Cloak.Vault, otp_app: :wanderer_app

  @impl GenServer
  def init(config) do
    cipher_key = decode_env!("CLOAK_KEY")
    fallback_cipher_key = decode_env!("FALLBACK_CLOAK_KEY")

    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: cipher_key, iv_length: 12
        },
        fallback: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: fallback_cipher_key, iv_length: 12
        }
      )

    {:ok, config}
  end

  @impl Cloak.Vault
  def encrypt(plaintext) do
    with {:ok, config} <- Cloak.Vault.read_config(@table_name) do
      Cloak.Vault.encrypt(config, plaintext)
    end
  end

  @impl Cloak.Vault
  def encrypt!(plaintext) do
    case Cloak.Vault.read_config(@table_name) do
      {:ok, config} ->
        Cloak.Vault.encrypt!(config, plaintext)

      {:error, error} ->
        raise error
    end
  end

  @impl Cloak.Vault
  def encrypt(plaintext, label) do
    with {:ok, config} <- Cloak.Vault.read_config(@table_name) do
      Cloak.Vault.encrypt(config, plaintext, label)
    end
  end

  @impl Cloak.Vault
  def encrypt!(plaintext, label) do
    case Cloak.Vault.read_config(@table_name) do
      {:ok, config} ->
        Cloak.Vault.encrypt!(config, plaintext, label)

      {:error, error} ->
        raise error
    end
  end

  @impl Cloak.Vault
  def decrypt(ciphertext) do
    with {:ok, config} <- Cloak.Vault.read_config(@table_name) do
      decrypt(config, ciphertext)
    end
  end

  @impl Cloak.Vault
  def decrypt!(ciphertext) do
    case Cloak.Vault.read_config(@table_name) do
      {:ok, config} ->
        decrypt!(config, ciphertext)

      {:error, error} ->
        raise error
    end
  end

  defp decode_env!(var, fallback_key \\ "OtPJXGfKNyOMWI7TdpcWgOlyNtD9AGSfoAdvEuTQIno=") do
    var
    |> System.get_env(fallback_key)
    |> Base.decode64!()
  end

  @doc false
  def decrypt(config, ciphertext) do
    case find_module_to_decrypt(config, ciphertext) do
      nil ->
        {:error, Cloak.MissingCipher.exception(vault: config[:vault], ciphertext: ciphertext)}

      {_label, {module, opts}} ->
        case module.decrypt(ciphertext, opts) do
          {:ok, :error} ->
            case find_fallback_module_to_decrypt(config, ciphertext) do
              nil ->
                {:ok, :error}

              {_label, {module, opts}} ->
                module.decrypt(ciphertext, opts)
            end

          {:ok, plaintext} ->
            {:ok, plaintext}

          error ->
            error
        end
    end
  end

  @doc false
  def decrypt!(config, ciphertext) do
    case decrypt(config, ciphertext) do
      {:ok, plaintext} ->
        plaintext

      {:error, error} ->
        raise error
    end
  end

  defp find_module_to_decrypt(config, ciphertext) do
    Enum.find(config[:ciphers], fn {_label, {module, opts}} ->
      module.can_decrypt?(ciphertext, opts)
    end)
  end

  defp find_fallback_module_to_decrypt(config, ciphertext) do
    Enum.find(config[:ciphers], fn {label, _} ->
      label == :fallback
    end)
  end
end
