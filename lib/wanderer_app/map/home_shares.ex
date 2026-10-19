defmodule WandererApp.Map.HomeShares do
  @moduledoc """
  Homes other maps have shared with this one.

  Sharing is one token. The map that shares hands it out; the map that wants to see the way in
  keeps it, together with the slug - and, when that map lives on another instance, where to find
  it. A share on this instance takes the same token and skips the trip over the wire, so the two
  cases stay one thing rather than two.

  A share never carries the whole chain: what comes back is the home and the routes that lead
  into it, which is what somebody standing outside needs and nothing more.
  """

  require Logger

  alias WandererApp.Api.MapHomeShare

  # what the far side is allowed to take its time over
  @timeout :timer.seconds(10)

  # a remote map is read rarely: its chain moves, but not between two clicks
  @cache_ttl :timer.minutes(5)

  @type share :: %{
          id: String.t(),
          label: String.t(),
          slug: String.t(),
          base_url: String.t() | nil,
          remote?: boolean()
        }

  @doc """
  The shares this map holds.
  """
  @spec list(String.t()) :: [share()]
  def list(map_id) do
    case MapHomeShare.by_map(%{map_id: map_id}) do
      {:ok, shares} ->
        Enum.map(shares, fn share ->
          %{
            id: share.id,
            label: share.label || share.slug,
            slug: share.slug,
            base_url: share.base_url,
            remote?: remote?(share.base_url)
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Keeps a share: a token, the map it points at, and where that map lives.
  """
  @spec add(String.t(), map()) :: {:ok, share()} | {:error, atom()}
  def add(map_id, %{"token" => token, "slug" => slug} = params) do
    base_url = params |> Map.get("base_url") |> normalise_url()
    label = params |> Map.get("label") |> blank_to_nil()

    with {:ok, _home} <- read(%{base_url: base_url, slug: slug, token: token}),
         {:ok, share} <-
           MapHomeShare.new(%{
             map_id: map_id,
             label: label,
             base_url: base_url,
             slug: String.trim(slug),
             token: String.trim(token)
           }) do
      {:ok,
       %{
         id: share.id,
         label: share.label || share.slug,
         slug: share.slug,
         base_url: share.base_url,
         remote?: remote?(share.base_url)
       }}
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :unreadable}
    end
  end

  def add(_map_id, _params), do: {:error, :invalid}

  @doc """
  Forgets a share.
  """
  @spec delete(String.t()) :: :ok | :error
  def delete(share_id) do
    with {:ok, share} <- MapHomeShare.by_id(share_id),
         :ok <- MapHomeShare.destroy(share) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  The homes behind this map's shares, as the context menu wants them.
  """
  @spec homes(String.t()) :: [map()]
  def homes(map_id) do
    case MapHomeShare.by_map(%{map_id: map_id}) do
      {:ok, shares} ->
        shares
        |> Enum.flat_map(fn share ->
          case read(share) do
            {:ok, %{"home" => %{"solar_system_id" => solar_system_id} = home}} ->
              [
                %{
                  share_id: share.id,
                  map_name: share.label || Map.get(home, "map_name", share.slug),
                  map_slug: share.slug,
                  remote?: remote?(share.base_url),
                  solar_system_id: solar_system_id
                }
              ]

            _ ->
              []
          end
        end)

      _ ->
        []
    end
  end

  @doc """
  The way into a shared home: the same graph a local home gives, whichever side of the wire it
  came from.
  """
  @spec ways_in(String.t()) :: {:ok, map()} | {:error, atom()}
  def ways_in(share_id) do
    with {:ok, share} <- MapHomeShare.by_id(share_id),
         {:ok, payload} <- read(share) do
      {:ok, payload}
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :unreadable}
    end
  end

  @doc """
  What a map hands out when somebody asks with its token.
  """
  @spec payload_for(map()) :: map()
  def payload_for(map) do
    %{
      "home" => %{
        "map_name" => map.name,
        "map_slug" => map.slug,
        "solar_system_id" => map.home_solar_system_id
      },
      "ways_in" =>
        map.id
        |> WandererApp.Map.Homes.ways_in(map.home_solar_system_id)
        |> WandererApp.Map.Homes.to_wire()
    }
  end

  defp read(%{base_url: base_url, slug: slug, token: token}) when base_url in [nil, ""],
    do: read_local(slug, token)

  defp read(%{base_url: base_url, slug: slug, token: token}),
    do: read_remote(base_url, slug, token)

  defp read_local(slug, token) do
    case WandererApp.Api.Map.get_map_by_slug(slug) do
      {:ok, %{home_solar_system_id: home, home_share_token: shared} = map}
      when is_integer(home) and is_binary(shared) ->
        if Plug.Crypto.secure_compare(shared, token) do
          {:ok, payload_for(map)}
        else
          {:error, :forbidden}
        end

      {:ok, _map} ->
        {:error, :not_shared}

      _ ->
        {:error, :no_such_map}
    end
  end

  defp read_remote(base_url, slug, token) do
    key = "home_share:#{base_url}:#{slug}"

    case WandererApp.Cache.lookup(key) do
      {:ok, payload} when is_map(payload) ->
        {:ok, payload}

      _ ->
        case fetch_remote(base_url, slug, token) do
          {:ok, payload} ->
            WandererApp.Cache.insert(key, payload, ttl: @cache_ttl)
            {:ok, payload}

          error ->
            error
        end
    end
  end

  defp fetch_remote(base_url, slug, token) do
    url = "#{base_url}/api/maps/#{URI.encode(slug)}/home"

    case Req.get(url,
           headers: [{"authorization", "Bearer #{token}"}],
           retry: false,
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"home" => _} = body}} ->
        {:ok, body}

      {:ok, %{status: status}} when status in [401, 403] ->
        {:error, :forbidden}

      {:ok, %{status: 404}} ->
        {:error, :no_such_map}

      {:ok, %{status: status}} ->
        Logger.warning(fn -> "[HomeShares] #{url} answered #{status}" end)
        {:error, :unreadable}

      {:error, reason} ->
        Logger.warning(fn -> "[HomeShares] could not reach #{url}: #{inspect(reason)}" end)
        {:error, :unreachable}
    end
  end

  defp normalise_url(nil), do: ""

  defp normalise_url(value) do
    case String.trim(value) do
      "" -> ""
      trimmed -> String.trim_trailing(trimmed, "/")
    end
  end

  defp remote?(base_url), do: base_url not in [nil, ""]

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
