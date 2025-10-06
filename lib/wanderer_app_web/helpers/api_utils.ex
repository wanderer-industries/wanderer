defmodule WandererAppWeb.Helpers.APIUtils do
  @moduledoc """
  Unified helper module for API operations:
  - Parameter parsing and validation
  - Map ID resolution
  - Standardized responses
  - JSON serialization
  """

  # Explicit imports to avoid unnecessary dependencies
  import Plug.Conn, only: [put_status: 2]
  import Phoenix.Controller, only: [json: 2]

  alias WandererApp.Api.Map, as: MapApi
  alias WandererApp.Api.MapSolarSystem
  require Logger

  # -----------------------------------------------------------------------------
  # Map ID Resolution
  # -----------------------------------------------------------------------------

  @spec fetch_map_id(map()) :: {:ok, String.t()} | {:error, String.t()}
  def fetch_map_id(params) do
    has_map_id = Map.has_key?(params, "map_id")
    has_slug = Map.has_key?(params, "slug")

    cond do
      has_map_id and has_slug ->
        {:error, "Cannot provide both map_id and slug parameters"}

      has_map_id ->
        id = params["map_id"]

        case Ecto.UUID.cast(id) do
          {:ok, _} -> {:ok, id}
          :error -> {:error, "Invalid UUID format for map_id: #{inspect(id)}"}
        end

      has_slug ->
        slug = params["slug"]

        case MapApi.get_map_by_slug(slug) do
          {:ok, %{id: id}} -> {:ok, id}
          _ -> {:error, "No map found for slug=#{inspect(slug)}"}
        end

      true ->
        {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"}
    end
  end

  # -----------------------------------------------------------------------------
  # Parameter Validators and Parsers
  # -----------------------------------------------------------------------------

  @spec require_param(map(), String.t()) :: {:ok, any()} | {:error, String.t()}
  def require_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) ->
        trimmed = String.trim(val)

        if trimmed == "" do
          {:error, "Param #{key} cannot be empty"}
        else
          {:ok, trimmed}
        end

      {:ok, val} ->
        {:ok, val}

      :error ->
        {:error, "Missing required param: #{key}"}
    end
  end

  @spec parse_int(binary() | integer()) :: {:ok, integer()} | {:error, String.t()}
  def parse_int(str) when is_binary(str) do
    Logger.debug("Parsing integer from: #{inspect(str)}")

    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "Invalid integer format: #{str}"}
    end
  end

  def parse_int(num) when is_integer(num), do: {:ok, num}
  def parse_int(other), do: {:error, "Expected integer or string, got: #{inspect(other)}"}

  @spec parse_int!(binary() | integer()) :: integer()
  def parse_int!(str) do
    case parse_int(str) do
      {:ok, num} -> num
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @spec validate_uuid(any()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_uuid(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, "Invalid UUID format: #{id}"}
    end
  end

  def validate_uuid(_), do: {:error, "ID must be a UUID string"}

  # -----------------------------------------------------------------------------
  # Parameter Extraction
  # -----------------------------------------------------------------------------

  @doc """
  Extract and validate parameters for upserting a system.
  Returns {:ok, attrs} or {:error, error_message}.
  """
  @spec extract_upsert_params(map()) :: {:ok, map()} | {:error, String.t()}
  def extract_upsert_params(params) when is_map(params) do
    required = ["solar_system_id"]

    optional = [
      "solar_system_name",
      "custom_name",
      "position_x",
      "position_y",
      "coordinates",
      "status",
      "visible",
      "description",
      "tag",
      "locked",
      "temporary_name",
      "labels"
    ]

    case Map.fetch(params, "solar_system_id") do
      :error ->
        {:error, "Missing solar_system_id in request body"}

      {:ok, _} ->
        params
        |> Map.take(required ++ optional)
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.into(%{})
        |> then(&{:ok, &1})
    end
  end

  @doc """
  Extract and validate parameters for updating a system.
  Returns {:ok, attrs} or {:error, error_message}.
  """
  @spec extract_update_params(map()) :: {:ok, map()} | {:error, String.t()}
  def extract_update_params(params) when is_map(params) do
    allowed = [
      "solar_system_name",
      "custom_name",
      "position_x",
      "position_y",
      "coordinates",
      "status",
      "visible",
      "description",
      "tag",
      "locked",
      "temporary_name",
      "labels"
    ]

    attrs =
      params
      |> Map.take(allowed)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    {:ok, attrs}
  end

  @spec normalize_connection_params(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_connection_params(params) do
    # Convert all keys to strings for consistent access
    string_params =
      for {k, v} <- params, into: %{} do
        {to_string(k), v}
      end

    # Define parameter mappings for normalization
    aliases = %{
      "source" => "solar_system_source",
      "source_id" => "solar_system_source",
      "target" => "solar_system_target",
      "target_id" => "solar_system_target"
    }

    # Normalize parameters using aliases
    normalized_params =
      Enum.reduce(aliases, string_params, fn {alias_key, std_key}, acc ->
        if Map.has_key?(acc, alias_key) && !Map.has_key?(acc, std_key) do
          Map.put(acc, std_key, acc[alias_key])
        else
          acc
        end
      end)

    # Handle required parameters
    with {:ok, src} <-
           parse_to_int(normalized_params["solar_system_source"], "solar_system_source"),
         {:ok, tgt} <-
           parse_to_int(normalized_params["solar_system_target"], "solar_system_target") do
      # Handle optional parameters with sane defaults
      type = normalized_params["type"] || 0
      mass_status = normalized_params["mass_status"] || 0
      time_status = normalized_params["time_status"] || 0
      ship_size_type = normalized_params["ship_size_type"] || 0
      # Coerce to boolean; accept "true"/"false", 1/0, etc.
      locked =
        case normalized_params["locked"] do
          val when val in [true, "true", 1, "1"] -> true
          val when val in [false, "false", 0, "0"] -> false
          nil -> false
          # keep unknowns for caller-side validation
          other -> other
        end

      custom_info = normalized_params["custom_info"]
      wormhole_type = normalized_params["wormhole_type"]

      # Build standardized attrs map
      attrs = %{
        "solar_system_source" => src,
        "solar_system_target" => tgt,
        "type" => parse_optional_int(type, 0),
        "mass_status" => parse_optional_int(mass_status, 0),
        "time_status" => parse_optional_int(time_status, 0),
        "ship_size_type" => parse_optional_int(ship_size_type, 0)
      }

      # Add non-nil optional attributes
      attrs = if is_nil(locked), do: attrs, else: Map.put(attrs, "locked", locked)
      attrs = if is_nil(custom_info), do: attrs, else: Map.put(attrs, "custom_info", custom_info)

      attrs =
        if is_nil(wormhole_type), do: attrs, else: Map.put(attrs, "wormhole_type", wormhole_type)

      {:ok, attrs}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  # Helper to handle various input formats
  defp parse_to_int(nil, field), do: {:error, "Missing #{field}"}
  defp parse_to_int(val, _field) when is_integer(val), do: {:ok, val}

  defp parse_to_int(val, field) when is_binary(val) do
    case Integer.parse(val) do
      {i, ""} -> {:ok, i}
      :error -> {:error, "Invalid #{field}: #{val}"}
      _ -> {:error, "Invalid #{field}: #{val}"}
    end
  end

  defp parse_to_int(val, field), do: {:error, "Invalid #{field} type: #{inspect(val)}"}

  defp parse_optional_int(nil, default), do: default
  defp parse_optional_int(i, _default) when is_integer(i), do: i

  defp parse_optional_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> default
    end
  end

  # -----------------------------------------------------------------------------
  # Standardized JSON Responses
  # -----------------------------------------------------------------------------

  @spec respond_data(Plug.Conn.t(), any(), atom() | integer()) :: Plug.Conn.t()
  def respond_data(conn, data, status \\ :ok) do
    conn
    |> put_status(status)
    |> json(%{data: data})
  end

  @spec error_response(Plug.Conn.t(), atom() | integer(), String.t(), map() | nil) ::
          Plug.Conn.t()
  def error_response(conn, status, message, details \\ nil) do
    body = if details, do: %{error: message, details: details}, else: %{error: message}

    conn
    |> put_status(status)
    |> json(body)
  end

  @spec error_not_found(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def error_not_found(conn, message), do: error_response(conn, :not_found, message)

  @doc """
  Formats error messages for consistent display.
  """
  @spec format_error(any()) :: String.t()
  def format_error(error) when is_binary(error), do: error
  def format_error(error) when is_atom(error), do: Atom.to_string(error)
  def format_error(error), do: inspect(error)

  # -----------------------------------------------------------------------------
  # JSON Serialization
  # -----------------------------------------------------------------------------

  @spec map_system_to_json(struct()) :: map()
  def map_system_to_json(system) do
    original = get_original_name(system.solar_system_id)

    # Determine the actual custom_name: if name differs from original, use it as custom_name
    actual_custom_name =
      if system.name != original and system.name not in [nil, ""],
        do: system.name,
        else: system.custom_name

    base =
      Map.take(system, ~w(
        id map_id solar_system_id temporary_name description tag labels
        locked visible status position_x position_y inserted_at updated_at
      )a)
      |> Map.put(:custom_name, actual_custom_name)

    name = pick_name(system)

    base
    |> Map.put(:original_name, original)
    |> Map.put(:name, name)
  end

  defp get_original_name(id) do
    case MapSolarSystem.by_solar_system_id(id) do
      {:ok, sys} -> sys.solar_system_name
      _ -> "System #{id}"
    end
  end

  defp pick_name(%{temporary_name: t, custom_name: c, name: n, solar_system_id: id} = system) do
    original = get_original_name(id)

    cond do
      t not in [nil, ""] -> t
      c not in [nil, ""] -> c
      # If name differs from original, it's a custom name
      n not in [nil, ""] and n != original -> n
      true -> original
    end
  end

  @spec connection_to_json(struct()) :: map()
  def connection_to_json(conn) do
    Map.take(conn, ~w(
      id map_id solar_system_source solar_system_target mass_status
      time_status ship_size_type type wormhole_type inserted_at updated_at
    )a)
  end
end
