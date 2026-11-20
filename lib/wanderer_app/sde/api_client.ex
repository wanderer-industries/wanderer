defmodule WandererApp.Sde.ApiClient do
  @moduledoc """
  Reads single records of EVE's static data from the SDE API
  (https://sde.evetech.net).

  ESI no longer serves static data from the 2026-11-19 compatibility date:
  `/universe/types/{id}`, `/universe/groups/{id}` and the other static
  `/universe` routes are gone. CCP points to the SDE API instead.

  `latest/` redirects to the current release, and record bodies are always
  gzipped. Req follows the redirect and decompresses the body.

  Records use the SDE field names (`typeID`, `groupID`, ...), and text
  fields such as `name` and `description` are maps keyed by language.
  """
  use Nebulex.Caching

  alias WandererApp.Cache

  @base_url "https://sde.evetech.net/tranquility/latest"
  @ttl :timer.hours(1)
  @user_agent "(wanderer-industries@proton.me; +https://github.com/wanderer-industries/wanderer)"

  @decorate cacheable(
              cache: Cache,
              key: "sde-type-#{type_id}",
              match: &__MODULE__.cacheable_result?/1,
              opts: [ttl: @ttl]
            )
  def get_type(type_id), do: get_record("types", type_id)

  @decorate cacheable(
              cache: Cache,
              key: "sde-group-#{group_id}",
              match: &__MODULE__.cacheable_result?/1,
              opts: [ttl: @ttl]
            )
  def get_group(group_id), do: get_record("groups", group_id)

  @doc """
  Returns the English text of a localized SDE field, or the value as is
  when it is not localized.
  """
  def localized(record, field) when is_map(record) do
    case Map.get(record, field) do
      %{"en" => text} -> text
      value -> value
    end
  end

  @doc false
  # Keep records and confirmed misses; retry anything else on the next call.
  def cacheable_result?({:ok, _record}), do: true
  def cacheable_result?({:error, :not_found}), do: true
  def cacheable_result?(_result), do: false

  defp get_record(table, key) do
    [
      base_url: @base_url,
      headers: [user_agent: "Wanderer/#{WandererApp.Env.vsn()} #{@user_agent}"],
      retry: false,
      receive_timeout: :timer.seconds(30)
    ]
    |> Keyword.merge(Application.get_env(:wanderer_app, :sde_req_options, []))
    |> Req.new()
    |> Req.get(url: "/#{table}/#{key}.json")
    |> case do
      {:ok, %{status: 200, body: record}} when is_map(record) -> {:ok, record}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end
