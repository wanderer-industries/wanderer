defmodule WandererApp.DeprecationTestHelpers do
  @moduledoc """
  Test helpers for verifying deprecation behavior.

  Provides assertions and utilities for testing deprecated endpoints
  and ensuring proper deprecation headers are present.
  """

  import ExUnit.Assertions
  import Plug.Conn

  @doc """
  Assert that a connection has proper deprecation headers.
  """
  def assert_deprecated_response(conn) do
    assert get_resp_header(conn, "deprecation") == ["true"]
    assert get_resp_header(conn, "sunset") != []
    assert get_resp_header(conn, "link") != []

    # Check for warning header
    warning = get_resp_header(conn, "warning")
    assert warning != []
    assert hd(warning) =~ "Deprecated API"

    conn
  end

  @doc """
  Assert that a connection was blocked due to deprecation.
  """
  def assert_deprecation_blocked(conn) do
    assert conn.status == 410
    assert conn.halted

    body = Jason.decode!(conn.resp_body)
    assert body["error"] == "Gone"
    assert body["message"] =~ "deprecated"
    assert body["sunset_date"] != nil

    conn
  end

  @doc """
  Set up test environment for legacy API testing.
  """
  def with_legacy_api_enabled(fun) do
    original = System.get_env("FEATURE_LEGACY_API")

    try do
      System.put_env("FEATURE_LEGACY_API", "true")
      fun.()
    after
      case original do
        nil -> System.delete_env("FEATURE_LEGACY_API")
        value -> System.put_env("FEATURE_LEGACY_API", value)
      end
    end
  end

  @doc """
  Set up test environment with legacy API disabled.
  """
  def with_legacy_api_disabled(fun) do
    original = System.get_env("FEATURE_LEGACY_API")

    try do
      System.put_env("FEATURE_LEGACY_API", "false")
      fun.()
    after
      case original do
        nil -> System.delete_env("FEATURE_LEGACY_API")
        value -> System.put_env("FEATURE_LEGACY_API", value)
      end
    end
  end

  @doc """
  Create a test case module for deprecated endpoints.
  """
  defmacro deprecated_api_test(endpoint_path, _opts \\ []) do
    quote do
      describe "deprecation behavior for #{unquote(endpoint_path)}" do
        test "returns deprecation headers when legacy API is enabled", %{conn: conn} do
          WandererApp.DeprecationTestHelpers.with_legacy_api_enabled(fn ->
            conn = get(conn, unquote(endpoint_path))
            assert_deprecated_response(conn)
          end)
        end

        test "blocks request when legacy API is disabled", %{conn: conn} do
          WandererApp.DeprecationTestHelpers.with_legacy_api_disabled(fn ->
            conn = get(conn, unquote(endpoint_path))
            assert_deprecation_blocked(conn)
          end)
        end
      end
    end
  end
end
