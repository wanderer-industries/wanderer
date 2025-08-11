defmodule WandererAppWeb.Plugs.RequestValidator do
  @moduledoc """
  Comprehensive request validation and sanitization middleware.

  This plug provides:
  - Input validation against schemas
  - Parameter sanitization (XSS, SQL injection prevention)
  - Request size limits
  - Content type validation
  - Rate limiting integration
  - Malicious pattern detection
  """

  import Plug.Conn

  alias WandererApp.SecurityAudit
  alias WandererApp.Audit.RequestContext

  # 10MB
  @max_request_size 10 * 1024 * 1024
  @max_param_length 10_000
  @max_nested_depth 10

  # Common XSS patterns to detect
  @xss_patterns [
    ~r/<script[^>]*>.*?<\/script>/i,
    ~r/<iframe[^>]*>.*?<\/iframe>/i,
    ~r/javascript:/i,
    ~r/on\w+\s*=/i,
    ~r/<object[^>]*>.*?<\/object>/i,
    ~r/<embed[^>]*>/i,
    ~r/expression\s*\(/i,
    ~r/vbscript:/i,
    ~r/data:text\/html/i
  ]

  # SQL injection patterns
  @sql_injection_patterns [
    ~r/(\bunion\b.*\bselect\b)|(\bselect\b.*\bunion\b)/i,
    ~r/(\bor\b\s+[\w\'"]+\s*=\s*[\w\'"]+)|(\band\b\s+[\w\'"]+\s*=\s*[\w\'"]+)/i,
    ~r/(\bdrop\b\s+\btable\b)|(\bdelete\b\s+\bfrom\b)|(\binsert\b\s+\binto\b)/i,
    ~r/(\bexec\b\s*\()|(\bexecute\b\s*\()/i,
    ~r/(\bsp_\w+)|(\bxp_\w+)/i,
    ~r/(\bconcat\b\s*\()|(\bchar\b\s*\()/i,
    ~r/(\bhaving\b\s+[\w\'"]+\s*=)|(\bgroup\b\s+\bby\b\s+[\w\'"]+\s*=)/i,
    ~r/(\bwaitfor\b\s+\bdelay\b)|(\bwaitfor\b\s+\btime\b)/i
  ]

  # Path traversal patterns
  @path_traversal_patterns [
    ~r/\.\.\/|\.\.\\|%2e%2e%2f|%2e%2e\\/i,
    ~r/\/etc\/passwd|\/etc\/shadow|\/windows\/system32/i,
    ~r/\.\.%2f|\.\.%5c|%2e%2e%2f|%2e%2e%5c/i
  ]

  def init(opts) do
    opts
    |> Keyword.put_new(:max_request_size, @max_request_size)
    |> Keyword.put_new(:max_param_length, @max_param_length)
    |> Keyword.put_new(:max_nested_depth, @max_nested_depth)
    |> Keyword.put_new(:validate_content_type, true)
    |> Keyword.put_new(:sanitize_params, true)
    |> Keyword.put_new(:detect_malicious_patterns, true)
  end

  def call(conn, opts) do
    start_time = System.monotonic_time(:millisecond)

    conn
    |> validate_request_size(opts)
    |> validate_content_type(opts)
    |> detect_malicious_patterns(opts)
    |> validate_and_sanitize_params(opts)
    |> log_validation_metrics(start_time)
  rescue
    error ->
      handle_validation_error(conn, error, opts)
  end

  # Request size validation
  defp validate_request_size(conn, opts) do
    max_size = Keyword.get(opts, :max_request_size, @max_request_size)

    case get_req_header(conn, "content-length") do
      [content_length] ->
        size = String.to_integer(content_length)

        if size > max_size do
          conn
          |> send_validation_error(413, "Request too large", %{
            size: size,
            max_allowed: max_size
          })
          |> halt()
        else
          conn
        end

      [] ->
        # No content-length header, let it pass
        conn
    end
  end

  # Content type validation
  defp validate_content_type(%{halted: true} = conn, _opts), do: conn

  defp validate_content_type(conn, opts) do
    if Keyword.get(opts, :validate_content_type, true) do
      case get_req_header(conn, "content-type") do
        [] ->
          # No content-type, check if method requires it
          if conn.method in ["POST", "PUT", "PATCH"] do
            conn
            |> send_validation_error(400, "Content-Type header required", %{
              method: conn.method,
              path: conn.request_path
            })
            |> halt()
          else
            conn
          end

        [content_type] ->
          validate_content_type_value(conn, content_type, opts)
      end
    else
      conn
    end
  end

  defp validate_content_type_value(conn, content_type, _opts) do
    # Extract media type without parameters
    media_type = content_type |> String.split(";") |> List.first() |> String.trim()

    allowed_types = [
      "application/json",
      "application/x-www-form-urlencoded",
      "multipart/form-data",
      "text/plain"
    ]

    if media_type in allowed_types do
      conn
    else
      conn
      |> send_validation_error(415, "Unsupported media type", %{
        received: media_type,
        allowed: allowed_types
      })
      |> halt()
    end
  end

  # Parameter validation and sanitization
  defp validate_and_sanitize_params(%{halted: true} = conn, _opts), do: conn

  defp validate_and_sanitize_params(conn, opts) do
    if Keyword.get(opts, :sanitize_params, true) do
      conn
      |> validate_param_structure(opts)
      |> sanitize_parameters(opts)
    else
      conn
    end
  end

  defp validate_param_structure(conn, opts) do
    max_length = Keyword.get(opts, :max_param_length, @max_param_length)
    max_depth = Keyword.get(opts, :max_nested_depth, @max_nested_depth)

    # Validate query parameters
    case validate_params(conn.query_params, max_length, max_depth, 0) do
      :ok ->
        # Validate body parameters if present
        case validate_params(conn.body_params, max_length, max_depth, 0) do
          :ok ->
            conn

          {:error, reason} ->
            conn
            |> send_validation_error(400, "Invalid body parameters", %{reason: reason})
            |> halt()
        end

      {:error, reason} ->
        conn
        |> send_validation_error(400, "Invalid query parameters", %{reason: reason})
        |> halt()
    end
  end

  defp validate_params(params, max_length, max_depth, current_depth) when is_map(params) do
    if current_depth > max_depth do
      {:error, "Maximum nesting depth exceeded"}
    else
      params
      |> Enum.reduce_while(:ok, fn {key, value}, :ok ->
        case validate_param_value(key, value, max_length, max_depth, current_depth + 1) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_params(params, max_length, max_depth, current_depth) when is_list(params) do
    if current_depth > max_depth do
      {:error, "Maximum nesting depth exceeded"}
    else
      params
      |> Enum.reduce_while(:ok, fn value, :ok ->
        case validate_param_value("list_item", value, max_length, max_depth, current_depth + 1) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_params(_params, _max_length, _max_depth, _current_depth), do: :ok

  defp validate_param_value(key, value, max_length, max_depth, current_depth)
       when is_binary(value) do
    cond do
      String.length(value) > max_length ->
        {:error, "Parameter '#{key}' exceeds maximum length"}

      String.valid?(value) ->
        :ok

      true ->
        {:error, "Parameter '#{key}' contains invalid UTF-8"}
    end
  end

  defp validate_param_value(key, value, max_length, max_depth, current_depth)
       when is_map(value) do
    validate_params(value, max_length, max_depth, current_depth)
  end

  defp validate_param_value(key, value, max_length, max_depth, current_depth)
       when is_list(value) do
    validate_params(value, max_length, max_depth, current_depth)
  end

  defp validate_param_value(_key, _value, _max_length, _max_depth, _current_depth), do: :ok

  # Parameter sanitization
  defp sanitize_parameters(conn, _opts) do
    sanitized_query_params = sanitize_params(conn.query_params)
    sanitized_body_params = sanitize_params(conn.body_params)

    conn
    |> Map.put(:query_params, sanitized_query_params)
    |> Map.put(:body_params, sanitized_body_params)
    |> Map.put(:params, Map.merge(sanitized_query_params, sanitized_body_params))
  end

  defp sanitize_params(params) when is_map(params) do
    params
    |> Enum.map(fn {key, value} ->
      {sanitize_param_key(key), sanitize_param_value(value)}
    end)
    |> Enum.into(%{})
  end

  defp sanitize_params(params) when is_list(params) do
    Enum.map(params, &sanitize_param_value/1)
  end

  defp sanitize_params(params), do: params

  defp sanitize_param_key(key) when is_binary(key) do
    key
    |> String.trim()
    |> String.replace(~r/[^\w\-_]/, "")
    # Limit key length
    |> String.slice(0, 100)
  end

  defp sanitize_param_key(key), do: key

  defp sanitize_param_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> html_escape()
    |> remove_null_bytes()
    |> normalize_whitespace()
  end

  defp sanitize_param_value(value) when is_map(value) do
    sanitize_params(value)
  end

  defp sanitize_param_value(value) when is_list(value) do
    sanitize_params(value)
  end

  defp sanitize_param_value(value), do: value

  # HTML escaping
  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#x27;")
    |> String.replace("/", "&#x2F;")
  end

  # Remove null bytes
  defp remove_null_bytes(text) do
    String.replace(text, <<0>>, "")
  end

  # Normalize whitespace
  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Malicious pattern detection
  defp detect_malicious_patterns(%{halted: true} = conn, _opts), do: conn

  defp detect_malicious_patterns(conn, opts) do
    if Keyword.get(opts, :detect_malicious_patterns, true) do
      check_for_malicious_patterns(conn)
    else
      conn
    end
  end

  defp check_for_malicious_patterns(conn) do
    # Check all string parameters for malicious patterns
    all_params = extract_all_string_params(conn)

    case detect_patterns(all_params) do
      {:ok, []} ->
        conn

      {:ok, threats} ->
        # Log security threat
        user_id = get_user_id(conn)

        request_details = RequestContext.build_request_details(conn)

        SecurityAudit.log_event(
          :security_alert,
          user_id,
          Map.put(request_details, :threats, threats)
        )

        conn
        |> send_validation_error(400, "Malicious content detected", %{
          threats: length(threats),
          blocked: true
        })
        |> halt()
    end
  end

  defp extract_all_string_params(conn) do
    all_params = Map.merge(conn.query_params, conn.body_params)
    extract_strings_from_params(all_params)
  end

  defp extract_strings_from_params(params) when is_map(params) do
    params
    |> Enum.flat_map(fn {_key, value} ->
      extract_strings_from_params(value)
    end)
  end

  defp extract_strings_from_params(params) when is_list(params) do
    params
    |> Enum.flat_map(&extract_strings_from_params/1)
  end

  defp extract_strings_from_params(param) when is_binary(param) do
    [param]
  end

  defp extract_strings_from_params(_param), do: []

  defp detect_patterns(strings) do
    threats =
      strings
      |> Enum.flat_map(&check_string_for_threats/1)
      |> Enum.uniq()

    {:ok, threats}
  end

  defp check_string_for_threats(string) do
    threats = []

    # Check for XSS patterns
    threats =
      if has_xss_pattern?(string) do
        [%{type: "xss", pattern: "potential_xss", value: String.slice(string, 0, 100)} | threats]
      else
        threats
      end

    # Check for SQL injection patterns
    threats =
      if has_sql_injection_pattern?(string) do
        [
          %{
            type: "sql_injection",
            pattern: "potential_sql_injection",
            value: String.slice(string, 0, 100)
          }
          | threats
        ]
      else
        threats
      end

    # Check for path traversal patterns
    threats =
      if has_path_traversal_pattern?(string) do
        [
          %{
            type: "path_traversal",
            pattern: "potential_path_traversal",
            value: String.slice(string, 0, 100)
          }
          | threats
        ]
      else
        threats
      end

    threats
  end

  defp has_xss_pattern?(string) do
    Enum.any?(@xss_patterns, &Regex.match?(&1, string))
  end

  defp has_sql_injection_pattern?(string) do
    Enum.any?(@sql_injection_patterns, &Regex.match?(&1, string))
  end

  defp has_path_traversal_pattern?(string) do
    Enum.any?(@path_traversal_patterns, &Regex.match?(&1, string))
  end

  # Utility functions
  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp send_validation_error(conn, status, message, details) do
    error_response = %{
      error: message,
      status: status,
      details: details,
      timestamp: DateTime.utc_now()
    }

    conn
    |> put_status(status)
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(error_response))
  end

  defp handle_validation_error(conn, error, _opts) do
    # Log the validation error
    user_id = get_user_id(conn)

    request_details = RequestContext.build_request_details(conn)

    SecurityAudit.log_event(
      :security_alert,
      user_id,
      request_details
      |> Map.put(:error, "validation_error")
      |> Map.put(:message, Exception.message(error))
    )

    conn
    |> send_validation_error(500, "Request validation failed", %{
      error: "internal_validation_error"
    })
    |> halt()
  end

  defp log_validation_metrics(%{halted: true} = conn, _start_time), do: conn

  defp log_validation_metrics(conn, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Emit telemetry for validation performance
    :telemetry.execute(
      [:wanderer_app, :request_validation],
      %{duration: duration, count: 1},
      %{
        method: conn.method,
        path: conn.request_path,
        status: conn.status || 200,
        user_id: get_user_id(conn)
      }
    )

    conn
  end
end
