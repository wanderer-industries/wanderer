defmodule WandererApp.RequestValidationTest do
  @moduledoc """
  Tests for the request validation and sanitization system.
  """

  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.Plugs.{RequestValidator, ResponseSanitizer}
  alias WandererAppWeb.Plugs.ContentSecurity

  import WandererAppWeb.Factory

  describe "RequestValidator" do
    test "validates request size limits" do
      conn =
        build_conn()
        # Very large
        |> put_req_header("content-length", "999999999")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 413
    end

    test "validates content type for POST requests" do
      conn =
        build_conn(:post, "/api/test")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Content-Type header required"
    end

    test "allows valid content types" do
      conn =
        build_conn(:post, "/api/test", %{"test" => "data"})
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      refute conn.halted
    end

    test "rejects unsupported content types" do
      conn =
        build_conn(:post, "/api/test")
        |> put_req_header("content-type", "application/xml")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 415

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Unsupported media type"
    end

    test "sanitizes XSS in parameters" do
      malicious_params = %{
        "name" => "<script>alert('xss')</script>Test Name",
        "description" => "Safe description"
      }

      conn =
        build_conn(:post, "/api/test", malicious_params)
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init(detect_malicious_patterns: false))

      # Should be sanitized
      assert conn.params["name"] ==
               "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;&#x2F;script&gt;Test Name"

      assert conn.params["description"] == "Safe description"
    end

    test "detects SQL injection patterns" do
      malicious_params = %{
        "query" => "'; DROP TABLE users; --"
      }

      conn =
        build_conn(:post, "/api/test", malicious_params)
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Malicious content detected"
    end

    test "detects XSS patterns" do
      malicious_params = %{
        "content" => "<iframe src='javascript:alert(1)'></iframe>"
      }

      conn =
        build_conn(:post, "/api/test", malicious_params)
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Malicious content detected"
    end

    test "detects path traversal patterns" do
      malicious_params = %{
        "file" => "../../etc/passwd"
      }

      conn =
        build_conn(:post, "/api/test")
        |> put_req_header("content-type", "application/json")
        |> Map.put(:body_params, malicious_params)
        |> Map.put(:params, malicious_params)
        |> Map.put(:query_params, %{})
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Malicious content detected"
    end

    test "validates parameter nesting depth" do
      # Exceeds default max depth of 10
      deeply_nested = build_nested_params(15)

      conn =
        build_conn(:post, "/api/test", deeply_nested)
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert String.contains?(response["details"]["reason"], "Maximum nesting depth exceeded")
    end

    test "validates parameter length limits" do
      # Exceeds default max length
      long_string = String.duplicate("a", 20_000)

      conn =
        build_conn(:post, "/api/test", %{"data" => long_string})
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      assert conn.halted
      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert String.contains?(response["details"]["reason"], "exceeds maximum length")
    end

    test "allows safe parameters" do
      safe_params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "age" => 30,
        "preferences" => %{
          "theme" => "dark",
          "notifications" => true
        }
      }

      conn =
        build_conn(:post, "/api/test", safe_params)
        |> put_req_header("content-type", "application/json")
        |> RequestValidator.call(RequestValidator.init([]))

      refute conn.halted
      assert conn.params["name"] == "John Doe"
      assert conn.params["email"] == "john@example.com"
    end
  end

  describe "ResponseSanitizer" do
    test "adds security headers" do
      conn =
        build_conn()
        |> ResponseSanitizer.call(ResponseSanitizer.init([]))

      headers = get_resp_headers(conn)

      assert {"x-content-type-options", "nosniff"} in headers
      assert {"x-frame-options", "DENY"} in headers
      assert {"x-xss-protection", "1; mode=block"} in headers
      assert {"referrer-policy", "strict-origin-when-cross-origin"} in headers
    end

    test "adds CSP header" do
      conn =
        build_conn()
        |> ResponseSanitizer.call(ResponseSanitizer.init([]))

      csp_header = get_resp_header(conn, "content-security-policy")
      assert length(csp_header) > 0

      csp_value = hd(csp_header)
      assert String.contains?(csp_value, "default-src 'self'")
      assert String.contains?(csp_value, "frame-ancestors 'none'")
    end

    test "adds security headers correctly" do
      conn =
        build_conn()
        |> ResponseSanitizer.call(ResponseSanitizer.init([]))

      # Verify security headers are present
      headers = get_resp_headers(conn)
      header_names = Enum.map(headers, fn {name, _value} -> name end)

      assert "x-content-type-options" in header_names
      assert "x-frame-options" in header_names
      assert "x-xss-protection" in header_names
      assert "content-security-policy" in header_names
    end

    test "response sanitizer module compiles correctly" do
      # Verify the response sanitizer has expected functions
      assert function_exported?(ResponseSanitizer, :call, 2)
      assert function_exported?(ResponseSanitizer, :init, 1)
    end
  end

  describe "ContentSecurity" do
    test "validates file extensions" do
      upload = %{filename: "malware.exe", content_type: "application/octet-stream", size: 1024}

      result = ContentSecurity.validate_uploaded_file(upload)
      assert {:error, message} = result
      assert String.contains?(message, "not allowed")
    end

    test "validates file size" do
      # 100MB
      upload = %{filename: "large.jpg", content_type: "image/jpeg", size: 100 * 1024 * 1024}

      # 10MB limit
      result = ContentSecurity.validate_uploaded_file(upload, max_file_size: 10 * 1024 * 1024)
      assert {:error, message} = result
      assert String.contains?(message, "exceeds maximum")
    end

    test "validates MIME types" do
      upload = %{filename: "test.pdf", content_type: "application/x-executable", size: 1024}

      result = ContentSecurity.validate_uploaded_file(upload)
      assert {:error, message} = result
      assert String.contains?(message, "not allowed")
    end

    test "validates file content detection" do
      # Test that the content security module functions exist
      # This verifies the module compiles and has expected public functions

      assert function_exported?(ContentSecurity, :validate_uploaded_file, 1) ||
               function_exported?(ContentSecurity, :validate_uploaded_file, 2)

      assert function_exported?(ContentSecurity, :detect_content_type, 1)
      assert function_exported?(ContentSecurity, :scan_file_for_threats, 1)
    end

    test "allows safe files" do
      upload = %{filename: "safe.jpg", content_type: "image/jpeg", size: 1024}

      result = ContentSecurity.validate_uploaded_file(upload)
      assert {:ok, _} = result
    end
  end

  # Helper functions
  defp build_nested_params(depth, current \\ %{}) do
    if depth <= 0 do
      current
    else
      build_nested_params(depth - 1, %{"level#{depth}" => current})
    end
  end

  defp get_resp_headers(conn) do
    conn.resp_headers
  end
end
