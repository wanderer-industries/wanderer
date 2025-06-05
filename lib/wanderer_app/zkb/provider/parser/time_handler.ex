defmodule WandererApp.Zkb.Provider.Parser.TimeHandler do
  @moduledoc """
  Handles time parsing and validation for killmails.
  Manages time-related operations and cutoff checks.
  """

  require Logger

  @type killmail :: map()
  @type cutoff_dt :: DateTime.t()
  @type time_result :: {:ok, DateTime.t()} | {:error, term()}
  @type validate_result :: {:ok, {killmail(), DateTime.t()}} | :older | :skip

  @doc """
  Gets the killmail time from any supported format.
  Returns `{:ok, DateTime.t()}` or `{:error, reason}`.
  """
  @spec get_killmail_time(killmail()) :: time_result()
  def get_killmail_time(%{"killmail_time" => time}) when is_binary(time),  do: parse_time(time)
  def get_killmail_time(%{"killTime"      => time}) when is_binary(time),  do: parse_time(time)
  def get_killmail_time(%{"zkb"           => %{"time" => time}}) when is_binary(time), do: parse_time(time)
  def get_killmail_time(_), do: {:error, :missing_time}

  @doc """
  Validates and attaches a killmail's timestamp against a cutoff.
  Returns:
    - `{:ok, {km_with_time, dt}}` if valid
    - `:older` if timestamp is before cutoff
    - `:skip` if timestamp is missing or unparseable
  """
  @spec validate_killmail_time(killmail(), cutoff_dt()) :: validate_result()
  def validate_killmail_time(km, cutoff_dt) do
    case get_killmail_time(km) do
      {:ok, km_dt} ->
        if older_than_cutoff?(km_dt, cutoff_dt) do
          :older
        else
          km_with_time = Map.put(km, "kill_time", km_dt)
          {:ok, {km_with_time, km_dt}}
        end

      {:error, reason} ->
        Logger.warning(
          "[TimeHandler] Failed to parse time for killmail #{inspect(Map.get(km, "killmail_id"))}: #{inspect(reason)}"
        )
        :skip
    end
  end

  @spec parse_time(String.t()) :: time_result()
  def parse_time(time_str) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _offset} ->
        {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}

      {:error, :invalid_format} ->
        case NaiveDateTime.from_iso8601(time_str) do
          {:ok, ndt} -> {:ok, DateTime.from_naive!(ndt, "Etc/UTC")}
          error     ->
            log_time_parse_error(time_str, error)
            error
        end

      error ->
        log_time_parse_error(time_str, error)
        error
    end
  end
  def parse_time(_), do: {:error, :invalid_time_format}

  @spec log_time_parse_error(String.t(), term()) :: :ok
  defp log_time_parse_error(time_str, error) do
    Logger.warning("[TimeHandler] Failed to parse time: #{time_str}, error: #{inspect(error)}")
  end

  @spec older_than_cutoff?(DateTime.t(), DateTime.t()) :: boolean()
  defp older_than_cutoff?(km_dt, cutoff_dt), do: DateTime.compare(km_dt, cutoff_dt) == :lt
end
