defmodule WandererAppWeb.Plugs.ContentSecurity do
  @moduledoc """
  Advanced content security and file upload validation.

  This plug provides:
  - File upload validation and sanitization
  - MIME type verification
  - File size limits
  - Malware detection patterns
  - Content scanning
  """

  import Plug.Conn

  alias WandererApp.SecurityAudit

  # 50MB
  @max_file_size 50 * 1024 * 1024
  @allowed_mime_types [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "text/plain",
    "text/csv",
    "application/json",
    "application/pdf",
    "application/zip"
  ]

  @dangerous_extensions [
    ".exe",
    ".bat",
    ".cmd",
    ".com",
    ".pif",
    ".scr",
    ".vbs",
    ".js",
    ".jar",
    ".app",
    ".deb",
    ".pkg",
    ".dmg",
    ".msi",
    ".php",
    ".asp",
    ".jsp",
    ".cgi",
    ".pl",
    ".py",
    ".rb"
  ]

  @malware_signatures [
    # Common malware file signatures (hex patterns)
    # MZ header (PE executables)
    "4d5a",
    # ZIP with suspicious content
    "504b0304",
    # 7-Zip
    "377abcaf271c",
    # RAR
    "526172211a0700",
    # GZIP
    "1f8b08"
  ]

  def init(opts) do
    opts
    |> Keyword.put_new(:max_file_size, @max_file_size)
    |> Keyword.put_new(:allowed_mime_types, @allowed_mime_types)
    |> Keyword.put_new(:scan_uploads, true)
    |> Keyword.put_new(:quarantine_suspicious, true)
  end

  def call(conn, opts) do
    case has_file_upload?(conn) do
      true ->
        conn
        |> validate_file_uploads(opts)
        |> scan_file_content(opts)

      false ->
        conn
    end
  end

  defp has_file_upload?(conn) do
    case get_req_header(conn, "content-type") do
      ["multipart/form-data" <> _] -> true
      _ -> false
    end
  end

  defp validate_file_uploads(conn, opts) do
    max_size = Keyword.get(opts, :max_file_size, @max_file_size)
    allowed_types = Keyword.get(opts, :allowed_mime_types, @allowed_mime_types)

    # This would be called during multipart parsing
    # For now, we'll add validation hooks
    conn
    |> put_private(:file_validation_opts, opts)
    |> put_private(:max_file_size, max_size)
    |> put_private(:allowed_mime_types, allowed_types)
  end

  def validate_uploaded_file(upload, opts \\ []) do
    max_size = Keyword.get(opts, :max_file_size, @max_file_size)
    allowed_types = Keyword.get(opts, :allowed_mime_types, @allowed_mime_types)

    with :ok <- validate_file_size(upload, max_size),
         :ok <- validate_file_extension(upload),
         :ok <- validate_mime_type(upload, allowed_types),
         :ok <- validate_file_content(upload) do
      {:ok, upload}
    else
      {:error, reason} ->
        log_file_validation_error(upload, reason)
        {:error, reason}
    end
  end

  defp validate_file_size(%{size: size}, max_size) when size > max_size do
    {:error, "File size #{size} exceeds maximum allowed size #{max_size}"}
  end

  defp validate_file_size(_upload, _max_size), do: :ok

  defp validate_file_extension(%{filename: filename}) do
    extension = Path.extname(filename) |> String.downcase()

    if extension in @dangerous_extensions do
      {:error, "File extension '#{extension}' is not allowed"}
    else
      :ok
    end
  end

  defp validate_file_extension(_upload), do: :ok

  defp validate_mime_type(%{content_type: content_type}, allowed_types) do
    if content_type in allowed_types do
      :ok
    else
      {:error, "MIME type '#{content_type}' is not allowed"}
    end
  end

  defp validate_mime_type(_upload, _allowed_types), do: :ok

  defp validate_file_content(%{path: path}) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        validate_file_binary_content(content)

      {:error, reason} ->
        {:error, "Could not read file: #{reason}"}
    end
  end

  defp validate_file_content(_upload), do: :ok

  defp validate_file_binary_content(content) do
    # Check file signature
    signature =
      content |> binary_part(0, min(byte_size(content), 16)) |> Base.encode16(case: :lower)

    # Check for malware signatures
    if Enum.any?(@malware_signatures, fn sig ->
         String.starts_with?(signature, sig)
       end) do
      {:error, "File contains suspicious binary signature"}
    else
      # Additional content validation
      validate_text_content(content)
    end
  end

  defp validate_text_content(content) do
    # Convert to string if possible and check for suspicious patterns
    case String.valid?(content) do
      true ->
        check_text_for_threats(content)

      false ->
        # Binary file, basic checks passed
        :ok
    end
  end

  defp check_text_for_threats(text) do
    suspicious_patterns = [
      ~r/eval\s*\(/i,
      ~r/exec\s*\(/i,
      ~r/system\s*\(/i,
      ~r/shell_exec/i,
      ~r/passthru/i,
      ~r/file_get_contents/i,
      ~r/file_put_contents/i,
      ~r/include\s*\(/i,
      ~r/require\s*\(/i,
      ~r/<\?php/i,
      ~r/<%.*%>/i,
      ~r/document\.write/i,
      ~r/window\.location/i,
      ~r/document\.cookie/i
    ]

    threats =
      Enum.filter(suspicious_patterns, fn pattern ->
        Regex.match?(pattern, text)
      end)

    if length(threats) > 0 do
      {:error, "File content contains #{length(threats)} suspicious patterns"}
    else
      :ok
    end
  end

  defp scan_file_content(conn, opts) do
    if Keyword.get(opts, :scan_uploads, true) do
      # This would integrate with actual malware scanning
      # For now, we'll add hooks for future integration
      conn
      |> put_private(:content_scan_enabled, true)
    else
      conn
    end
  end

  defp log_file_validation_error(upload, reason) do
    SecurityAudit.log_event(:security_alert, nil, %{
      type: "file_validation_error",
      filename: upload[:filename],
      content_type: upload[:content_type],
      size: upload[:size],
      reason: reason,
      timestamp: DateTime.utc_now()
    })
  end

  # Public API for manual file validation
  def scan_file_for_threats(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        scan_content_for_threats(content)

      {:error, reason} ->
        {:error, "Could not read file: #{reason}"}
    end
  end

  def scan_content_for_threats(content) do
    threats = []

    # Check binary signatures
    threats =
      case check_binary_signatures(content) do
        [] -> threats
        binary_threats -> binary_threats ++ threats
      end

    # Check text content if valid UTF-8
    threats =
      case String.valid?(content) do
        true ->
          case check_text_for_threats(content) do
            :ok -> threats
            {:error, text_threats} -> [text_threats | threats]
          end

        false ->
          threats
      end

    case threats do
      [] -> {:ok, :clean}
      _ -> {:error, threats}
    end
  end

  defp check_binary_signatures(content) do
    signature =
      content
      |> binary_part(0, min(byte_size(content), 32))
      |> Base.encode16(case: :lower)

    @malware_signatures
    |> Enum.filter(fn sig -> String.contains?(signature, sig) end)
    |> Enum.map(fn sig -> "suspicious_signature_#{sig}" end)
  end

  # Rate limiting for file uploads
  def check_upload_rate_limit(user_id, opts \\ []) do
    max_uploads_per_hour = Keyword.get(opts, :max_uploads_per_hour, 100)
    # 500MB
    max_size_per_hour = Keyword.get(opts, :max_size_per_hour, 500 * 1024 * 1024)

    # This would integrate with your rate limiting system
    # For now, return ok
    {:ok,
     %{
       uploads_remaining: max_uploads_per_hour,
       size_remaining: max_size_per_hour
     }}
  end

  # Content type detection (more reliable than headers)
  def detect_content_type(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        detect_content_type_from_binary(content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_content_type_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, "image/jpeg"}

  defp detect_content_type_from_binary(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>
       ),
       do: {:ok, "image/png"}

  defp detect_content_type_from_binary(<<"GIF87a", _::binary>>), do: {:ok, "image/gif"}
  defp detect_content_type_from_binary(<<"GIF89a", _::binary>>), do: {:ok, "image/gif"}

  defp detect_content_type_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: {:ok, "image/webp"}

  defp detect_content_type_from_binary(<<"%PDF-", _::binary>>), do: {:ok, "application/pdf"}

  defp detect_content_type_from_binary(<<"PK", 0x03, 0x04, _::binary>>),
    do: {:ok, "application/zip"}

  defp detect_content_type_from_binary(<<"PK", 0x05, 0x06, _::binary>>),
    do: {:ok, "application/zip"}

  defp detect_content_type_from_binary(<<"PK", 0x07, 0x08, _::binary>>),
    do: {:ok, "application/zip"}

  defp detect_content_type_from_binary(content) do
    # Try to detect as text
    if String.valid?(content) do
      {:ok, "text/plain"}
    else
      {:ok, "application/octet-stream"}
    end
  end
end
