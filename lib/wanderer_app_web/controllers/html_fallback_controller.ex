defmodule WandererAppWeb.HtmlFallbackController do
  @moduledoc """
  Fallback controller for HTML browser endpoints.

  This controller handles errors that occur in browser-facing endpoints,
  rendering appropriate HTML error pages or redirects.
  """

  use WandererAppWeb, :controller

  # Handles not_found errors by rendering 404 page
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(WandererAppWeb.ErrorHTML)
    |> render(:"404")
  end

  # Handles unauthorized access - redirect to login
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_flash(:error, "You must be logged in to access this page")
    |> redirect(to: "/auth/eve")
  end

  # Handles forbidden access
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_flash(:error, "You don't have permission to access this resource")
    |> put_view(WandererAppWeb.ErrorHTML)
    |> render(:"403")
  end

  # Handles invalid parameters - redirect back with error
  def call(conn, {:error, :invalid_params}) do
    conn
    |> put_flash(:error, "Invalid parameters provided")
    |> redirect(to: get_fallback_path(conn))
  end

  # Handles validation errors - redirect back with errors
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = format_changeset_errors(changeset)

    conn
    |> put_flash(:error, "Please correct the following errors: #{Enum.join(errors, ", ")}")
    |> redirect(to: get_fallback_path(conn))
  end

  # Handles any other errors - show generic error page
  def call(conn, _error) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(WandererAppWeb.ErrorHTML)
    |> render(:"500")
  end

  # Helper to get the appropriate redirect path
  defp get_fallback_path(conn) do
    case get_req_header(conn, "referer") do
      [referer] -> 
        case URI.parse(referer) do
          %URI{path: path} when is_binary(path) ->
            # Ensure path starts with "/" and doesn't contain ".." to prevent open redirects
            if String.starts_with?(path, "/") and not String.contains?(path, "..") do
              path
            else
              "/"
            end
          _ -> 
            "/"
        end
      _ -> 
        "/"
    end
  end

  # Helper to format changeset errors for flash messages
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, errors} ->
      Enum.map(errors, &"#{field} #{&1}")
    end)
  end
end
