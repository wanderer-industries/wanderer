defmodule WandererAppWeb.ApiRouterHelpers do
  @moduledoc """
  Helper functions for version-aware API routing.
  """

  alias WandererAppWeb.Plugs.ApiVersioning

  def version_specific_action(base_action, version) do
    String.to_atom("#{base_action}_v#{String.replace(version, ".", "_")}")
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
          page: String.to_integer(conn.params["page"] || "1"),
          per_page:
            min(
              String.to_integer(conn.params["per_page"] || "#{version_config.default_page_size}"),
              version_config.max_page_size
            )
        }

      _ ->
        # JSON:API pagination
        page_params = conn.params["page"] || %{}

        %{
          number: String.to_integer(page_params["number"] || "1"),
          size:
            min(
              String.to_integer(page_params["size"] || "#{version_config.default_page_size}"),
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
end
