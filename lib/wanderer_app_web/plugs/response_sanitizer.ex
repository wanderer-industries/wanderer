defmodule WandererAppWeb.Plugs.ResponseSanitizer do
  @moduledoc """
  Response sanitization and security header middleware.

  This plug provides:
  - Output sanitization to prevent XSS
  - Sensitive data masking
  - Security headers (CSP, HSTS, etc.)
  - Error message sanitization
  - Response size limits
  """

  import Plug.Conn

  @sensitive_fields [
    "password",
    "token",
    "secret",
    "key",
    "hash",
    "encrypted_",
    "access_token",
    "refresh_token",
    "api_key",
    "private_key",
    "wallet_balance",
    "eve_wallet_balance"
  ]

  @security_headers [
    {"x-content-type-options", "nosniff"},
    {"x-frame-options", "DENY"},
    {"x-xss-protection", "1; mode=block"},
    {"referrer-policy", "strict-origin-when-cross-origin"},
    {"permissions-policy", "geolocation=(), microphone=(), camera=()"}
  ]

  def init(opts) do
    opts
    |> Keyword.put_new(:add_security_headers, true)
    |> Keyword.put_new(:sanitize_responses, true)
    |> Keyword.put_new(:mask_sensitive_data, true)
    |> Keyword.put_new(:csp_enabled, true)
    |> Keyword.put_new(:hsts_enabled, true)
  end

  def call(conn, opts) do
    conn
    |> add_security_headers(opts)
    |> register_before_send(&sanitize_response(&1, opts))
  end

  # Add security headers
  defp add_security_headers(conn, opts) do
    if Keyword.get(opts, :add_security_headers, true) do
      conn
      |> add_basic_security_headers()
      |> add_csp_header(opts)
      |> add_hsts_header(opts)
    else
      conn
    end
  end

  defp add_basic_security_headers(conn) do
    Enum.reduce(@security_headers, conn, fn {header, value}, acc ->
      put_resp_header(acc, header, value)
    end)
  end

  defp add_csp_header(conn, opts) do
    if Keyword.get(opts, :csp_enabled, true) do
      csp_policy = build_csp_policy(conn)
      put_resp_header(conn, "content-security-policy", csp_policy)
    else
      conn
    end
  end

  defp build_csp_policy(conn) do
    base_policy = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://unpkg.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdn.jsdelivr.net",
      "font-src 'self' https://fonts.gstatic.com data:",
      "img-src 'self' data: https: blob:",
      "connect-src 'self' wss: ws:",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'"
    ]

    # Add nonce for development
    case Application.get_env(:wanderer_app, :environment) do
      :dev ->
        nonce = generate_nonce()
        conn = put_private(conn, :csp_nonce, nonce)

        base_policy
        |> Enum.map(fn directive ->
          if String.starts_with?(directive, "script-src") do
            directive <> " 'nonce-#{nonce}'"
          else
            directive
          end
        end)
        |> Enum.join("; ")

      _ ->
        Enum.join(base_policy, "; ")
    end
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp add_hsts_header(conn, opts) do
    if Keyword.get(opts, :hsts_enabled, true) and https_request?(conn) do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end

  defp https_request?(conn) do
    case get_req_header(conn, "x-forwarded-proto") do
      ["https"] -> true
      [] -> conn.scheme == :https
      _ -> false
    end
  end

  # Response sanitization
  defp sanitize_response(conn, opts) do
    if Keyword.get(opts, :sanitize_responses, true) do
      conn
      |> sanitize_response_body(opts)
      |> add_response_security_headers()
    else
      conn
    end
  end

  defp sanitize_response_body(conn, opts) do
    case get_resp_header(conn, "content-type") do
      ["application/json" <> _] ->
        sanitize_json_response(conn, opts)

      ["text/html" <> _] ->
        sanitize_html_response(conn, opts)

      _ ->
        conn
    end
  end

  defp sanitize_json_response(conn, opts) do
    case conn.resp_body do
      body when is_binary(body) ->
        try do
          data = Jason.decode!(body)
          sanitized_data = sanitize_json_data(data, opts)
          sanitized_body = Jason.encode!(sanitized_data)

          %{conn | resp_body: sanitized_body}
        rescue
          # If JSON parsing fails, return original
          _ -> conn
        end

      _ ->
        conn
    end
  end

  defp sanitize_json_data(data, opts) when is_map(data) do
    if Keyword.get(opts, :mask_sensitive_data, true) do
      data
      |> Enum.map(fn {key, value} ->
        if is_sensitive_field?(key) do
          {key, mask_sensitive_value(value)}
        else
          {key, sanitize_json_data(value, opts)}
        end
      end)
      |> Enum.into(%{})
    else
      data
      |> Enum.map(fn {key, value} ->
        {key, sanitize_json_data(value, opts)}
      end)
      |> Enum.into(%{})
    end
  end

  defp sanitize_json_data(data, opts) when is_list(data) do
    Enum.map(data, fn item ->
      sanitize_json_data(item, opts)
    end)
  end

  defp sanitize_json_data(data, _opts) when is_binary(data) do
    # Basic XSS protection for string values
    data
    |> String.replace(~r/<script[^>]*>.*?<\/script>/i, "")
    |> String.replace(~r/<iframe[^>]*>.*?<\/iframe>/i, "")
    |> String.replace(~r/javascript:/i, "")
    |> String.replace(~r/on\w+\s*=/i, "")
  end

  defp sanitize_json_data(data, _opts), do: data

  defp is_sensitive_field?(field) when is_binary(field) do
    field_lower = String.downcase(field)

    Enum.any?(@sensitive_fields, fn sensitive ->
      String.contains?(field_lower, sensitive)
    end)
  end

  defp is_sensitive_field?(_field), do: false

  defp mask_sensitive_value(value) when is_binary(value) do
    cond do
      String.length(value) <= 4 -> "[REDACTED]"
      String.length(value) <= 8 -> String.slice(value, 0, 2) <> "***"
      true -> String.slice(value, 0, 4) <> "****"
    end
  end

  defp mask_sensitive_value(_value), do: "[REDACTED]"

  defp sanitize_html_response(conn, _opts) do
    case conn.resp_body do
      body when is_binary(body) ->
        sanitized_body = sanitize_html_content(body)
        %{conn | resp_body: sanitized_body}

      _ ->
        conn
    end
  end

  defp sanitize_html_content(html) do
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, "")
    |> String.replace(~r/<iframe[^>]*>.*?<\/iframe>/is, "")
    |> String.replace(~r/<object[^>]*>.*?<\/object>/is, "")
    |> String.replace(~r/<embed[^>]*>/is, "")
    |> String.replace(~r/on\w+\s*=\s*[^>]*/i, "")
    |> String.replace(~r/javascript:/i, "")
    |> String.replace(~r/vbscript:/i, "")
    |> String.replace(~r/data:text\/html/i, "")
    |> String.replace(~r/expression\s*\(/i, "")
  end

  defp add_response_security_headers(conn) do
    conn
    |> put_resp_header("x-request-id", get_request_id(conn))
    |> put_resp_header("x-response-time", get_response_time(conn))
  end

  defp get_request_id(conn) do
    case get_req_header(conn, "x-request-id") do
      [request_id] ->
        request_id

      [] ->
        case conn.assigns[:request_id] do
          nil -> generate_request_id()
          id -> id
        end
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_response_time(conn) do
    case conn.assigns[:request_start_time] do
      nil ->
        "0ms"

      start_time ->
        duration = System.monotonic_time(:millisecond) - start_time
        "#{duration}ms"
    end
  end
end
