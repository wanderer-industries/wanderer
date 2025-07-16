defmodule WandererAppWeb.ApiRouterHelpers do
  @moduledoc """
  Helper functions for version-aware API routing.
  """

  alias WandererAppWeb.Plugs.ApiVersioning

  def version_specific_action(base_action, version) do
    # Validate version format before converting to atom
    validated_version =
      case validate_version_format(version) do
        :ok -> String.replace(version, ".", "_")
        # fallback to v1
        :error -> "1"
      end

    String.to_atom("#{base_action}_v#{validated_version}")
  end

  def supports_feature?(conn, feature) do
    version = conn.assigns[:api_version]
    ApiVersioning.version_supports_feature?(version, feature)
  end

  def get_pagination_params(conn) do
    version_config = conn.assigns[:version_config]

    case conn.assigns[:api_version] do
      "1.0" ->
        # Legacy pagination
        %{
          page: parse_integer(conn.params["page"], 1),
          per_page:
            min(
              parse_integer(conn.params["per_page"], version_config.default_page_size),
              version_config.max_page_size
            )
        }

      _ ->
        # JSON:API pagination
        page_params = conn.params["page"] || %{}

        %{
          number: parse_integer(page_params["number"], 1),
          size:
            min(
              parse_integer(page_params["size"], version_config.default_page_size),
              version_config.max_page_size
            )
        }
    end
  end

  def get_filter_params(conn) do
    if supports_feature?(conn, :filtering) do
      conn.params["filter"] || %{}
    else
      %{}
    end
  end

  def get_sort_params(conn) do
    if supports_feature?(conn, :sorting) do
      conn.params["sort"]
    else
      nil
    end
  end

  def get_include_params(conn) do
    if supports_feature?(conn, :includes) do
      case conn.params["include"] do
        include when is_binary(include) -> String.split(include, ",")
        include when is_list(include) -> include
        _ -> []
      end
    else
      []
    end
  end

  def get_sparse_fields_params(conn) do
    if supports_feature?(conn, :sparse_fieldsets) do
      conn.params["fields"] || %{}
    else
      %{}
    end
  end

  # Private helper functions

  # Safe integer parsing helper
  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_value, default), do: default

  # Validate version format (digits separated by dots or just digits)
  defp validate_version_format(version) when is_binary(version) do
    if Regex.match?(~r/^\d+(\.\d+)*$/, version) do
      :ok
    else
      :error
    end
  end

  defp validate_version_format(_), do: :error
end
