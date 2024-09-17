defmodule WandererAppWeb.Helpers.CSP do
  @moduledoc false

  # sobelow_skip ["Traversal.FileModule"]
  @spec integrity_hash(priv_path :: Path.t()) :: String.t() | nil
  def integrity_hash(priv_path) do
    %{path: priv_path} = URI.parse(priv_path)

    :wanderer_app
    |> Application.app_dir("priv/static/")
    |> Path.join(priv_path)
    |> File.read()
    |> case do
      {:ok, content} ->
        hash =
          :sha512
          |> :crypto.hash(content)
          |> Base.encode64()

        "sha512-#{hash}"

      {:error, :enoent} ->
        nil
    end
  end

  @spec nonce(conn :: Plug.Conn.t(), type :: atom) :: String.t()
  def nonce(conn, type) do
    conn.assigns[String.to_existing_atom("#{type}_src_nonce")]
  end
end
