defmodule WandererAppWeb.Helpers.AshJsonApiForwarder do
  @moduledoc """
  Helper module to forward legacy controller actions to AshJsonApi endpoints.

  This maintains backward compatibility while migrating to AshJsonApi by
  translating legacy request formats to JSON:API format and responses back.
  """

  import Plug.Conn
  require Logger

  @doc """
  Forwards a request to an AshJsonApi endpoint and translates the response.

  Options:
    - :resource - The Ash resource module
    - :action - The Ash action to call
    - :path_params - Additional path parameters to merge
    - :query_params - Additional query parameters to merge
    - :transform_params - Function to transform params before forwarding
    - :transform_response - Function to transform response before returning
  """
  def forward(conn, opts) do
    resource = Keyword.fetch!(opts, :resource)
    action = Keyword.fetch!(opts, :action)

    # Build JSON:API compliant request
    json_api_params = build_json_api_params(conn, opts)

    # Call the Ash action
    result = call_ash_action(resource, action, json_api_params, conn)

    # Transform and return response
    handle_ash_result(conn, result, opts)
  end

  defp build_json_api_params(conn, opts) do
    params = conn.params

    # Apply parameter transformation if provided
    params =
      if transform = opts[:transform_params] do
        transform.(params)
      else
        params
      end

    # Merge additional params
    params =
      params
      |> Map.merge(opts[:path_params] || %{})
      |> Map.merge(opts[:query_params] || %{})

    # Convert to JSON:API format based on action
    case opts[:action] do
      :create -> wrap_for_create(params)
      :update -> wrap_for_update(params)
      _ -> params
    end
  end

  defp wrap_for_create(params) do
    %{
      "data" => %{
        "type" => resource_type(params),
        "attributes" => Map.drop(params, ["type", "id"])
      }
    }
  end

  defp wrap_for_update(params) do
    %{
      "data" => %{
        "type" => resource_type(params),
        "id" => params["id"],
        "attributes" => Map.drop(params, ["type", "id"])
      }
    }
  end

  defp resource_type(params) do
    # Try to infer from params or use default
    params["type"] || "resource"
  end

  defp call_ash_action(resource, action, params, conn) do
    # Build options with actor from conn  
    opts = [
      actor: conn.assigns[:current_user],
      tenant: conn.assigns[:tenant],
      domain: WandererApp.Api
    ]

    # Call the appropriate Ash function with correct signatures
    case action do
      :read ->
        query = resource |> Ash.Query.new() |> Ash.Query.set_context(params)
        Ash.read(query, opts)

      :create ->
        attrs = extract_attributes(params)
        changeset = Ash.Changeset.for_create(resource, :create, attrs)
        Ash.create(changeset, opts)

      :update ->
        with id when is_binary(id) <- params["id"],
             {:ok, record} <- Ash.get(resource, id, opts),
             attrs <- extract_attributes(params),
             changeset <- Ash.Changeset.for_update(record, :update, attrs) do
          Ash.update(changeset, opts)
        end

      :destroy ->
        with id when is_binary(id) <- params["id"],
             {:ok, record} <- Ash.get(resource, id, opts),
             changeset <- Ash.Changeset.for_destroy(record, :destroy) do
          Ash.destroy(changeset, opts)
        end

      custom ->
        # For custom actions, build appropriate input and run through domain
        input = Ash.ActionInput.for_action(resource, custom, params)
        Ash.run_action(input, opts)
    end
  end

  defp handle_ash_result(conn, {:ok, result}, opts) do
    # Transform response if transformer provided
    response =
      if transform = opts[:transform_response] do
        transform.(result)
      else
        translate_to_legacy_format(result)
      end

    # Map action to appropriate HTTP status code
    status =
      case opts[:action] do
        :create -> 201
        :destroy -> 204
        _ -> 200
      end

    maybe_send_json_response(conn, status, response)
  end

  defp handle_ash_result(conn, {:error, error}, _opts) do
    error_response = format_error(error)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(error_response.status, Jason.encode!(error_response.body))
  end

  defp translate_to_legacy_format(result) when is_list(result) do
    %{"data" => Enum.map(result, &resource_to_legacy/1)}
  end

  defp translate_to_legacy_format(result) do
    %{"data" => resource_to_legacy(result)}
  end

  defp resource_to_legacy(resource) when is_struct(resource) do
    # Convert Ash resource to legacy format using proper struct introspection
    resource_module = resource.__struct__

    if function_exported?(resource_module, :__ash_resource__, 0) do
      attributes =
        resource_module
        |> Ash.Resource.Info.attributes()
        |> Enum.map(& &1.name)

      Map.take(resource, attributes)
    else
      # Fallback for non-Ash structs
      Map.from_struct(resource)
    end
  end

  defp resource_to_legacy(resource), do: resource

  defp format_error(error) when is_binary(error) do
    %{status: 400, body: %{"error" => error}}
  end

  defp format_error(%Ash.Error.Invalid{} = error) do
    %{
      status: 422,
      body: %{
        "errors" =>
          Enum.map(error.errors, fn e ->
            %{
              "field" => to_string(e.field || "base"),
              "message" => e.message || "Invalid value"
            }
          end)
      }
    }
  end

  defp format_error(_error) do
    %{status: 500, body: %{"error" => "Internal server error"}}
  end

  # Helper to extract attributes from JSON:API or direct params
  defp extract_attributes(%{"data" => %{"attributes" => attrs}}), do: attrs
  defp extract_attributes(params), do: Map.drop(params, ["id", "type"])

  # Helper to handle HTTP 204 responses correctly
  defp maybe_send_json_response(conn, 204, _response) do
    send_resp(conn, 204, "")
  end

  defp maybe_send_json_response(conn, status, response) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(response))
  end
end
