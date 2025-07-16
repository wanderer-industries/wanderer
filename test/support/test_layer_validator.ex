defmodule WandererApp.Support.TestLayerValidator do
  @moduledoc """
  Validates that tests are properly categorized and follow the test pyramid structure.

  This module ensures that:
  - Unit tests don't hit the database or external services
  - Integration tests properly use real dependencies
  - Contract tests validate API contracts
  - E2E tests exercise full user journeys
  """

  def validate_test_layers do
    # Get all test files
    test_files = get_all_test_files()

    # Validate each test file
    Enum.each(test_files, &validate_test_file/1)
  end

  defp get_all_test_files do
    Path.wildcard("test/**/*_test.exs")
    |> Enum.reject(&String.contains?(&1, "support/"))
  end

  defp validate_test_file(file_path) do
    content = File.read!(file_path)

    # Extract test tags from the file
    tags = extract_tags_from_content(content)

    # Validate based on directory structure
    case get_test_layer_from_path(file_path) do
      :unit -> validate_unit_test(file_path, content, tags)
      :integration -> validate_integration_test(file_path, content, tags)
      :contract -> validate_contract_test(file_path, content, tags)
      :e2e -> validate_e2e_test(file_path, content, tags)
      :performance -> validate_performance_test(file_path, content, tags)
      :unknown -> warn_unknown_test_layer(file_path)
    end
  end

  defp get_test_layer_from_path(file_path) do
    cond do
      String.contains?(file_path, "test/unit/") -> :unit
      String.contains?(file_path, "test/integration/") -> :integration
      String.contains?(file_path, "test/contract/") -> :contract
      String.contains?(file_path, "test/e2e/") -> :e2e
      String.contains?(file_path, "test/performance/") -> :performance
      true -> :unknown
    end
  end

  defp extract_tags_from_content(content) do
    Regex.scan(~r/@tag\s+:(\w+)/, content, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_atom/1)
  end

  defp validate_unit_test(file_path, content, tags) do
    # Unit tests should be tagged as :unit
    unless :unit in tags do
      warn("Unit test #{file_path} missing @tag :unit")
    end

    # Unit tests should not use real database operations
    if String.contains?(content, "Ecto.Adapters.SQL.Sandbox.checkout") do
      warn("Unit test #{file_path} should not use database sandbox")
    end

    # Unit tests should not make HTTP requests
    if String.contains?(content, "HTTPoison") || String.contains?(content, "Tesla") do
      warn("Unit test #{file_path} should not make HTTP requests")
    end

    # Unit tests should use mocks for external dependencies
    unless String.contains?(content, "import Mox") ||
             String.contains?(content, "use WandererApp.Support.MockSetup") do
      warn("Unit test #{file_path} should use mocks for external dependencies")
    end
  end

  defp validate_integration_test(file_path, content, tags) do
    # Integration tests should be tagged as :integration
    unless :integration in tags do
      warn("Integration test #{file_path} missing @tag :integration")
    end

    # Integration tests should use database sandbox
    unless String.contains?(content, "DataCase") || String.contains?(content, "ConnCase") do
      warn("Integration test #{file_path} should use DataCase or ConnCase")
    end
  end

  defp validate_contract_test(file_path, content, tags) do
    # Contract tests should be tagged as :contract
    unless :contract in tags do
      warn("Contract test #{file_path} missing @tag :contract")
    end

    # Contract tests should validate API contracts
    unless String.contains?(content, "OpenAPI") || String.contains?(content, "schema") do
      warn("Contract test #{file_path} should validate API contracts")
    end
  end

  defp validate_e2e_test(file_path, content, tags) do
    # E2E tests should be tagged as :e2e
    unless :e2e in tags do
      warn("E2E test #{file_path} missing @tag :e2e")
    end

    # E2E tests should use browser automation
    unless String.contains?(content, "Wallaby") || String.contains?(content, "Hound") do
      warn("E2E test #{file_path} should use browser automation")
    end
  end

  defp validate_performance_test(file_path, content, tags) do
    # Performance tests should be tagged as :performance
    unless :performance in tags do
      warn("Performance test #{file_path} missing @tag :performance")
    end

    # Performance tests should use benchmarking tools
    unless String.contains?(content, "Benchee") || String.contains?(content, "Performance") do
      warn("Performance test #{file_path} should use performance monitoring")
    end
  end

  defp warn_unknown_test_layer(file_path) do
    warn("Test #{file_path} is not in a recognized test layer directory")
  end

  defp warn(message) do
    IO.puts(:stderr, "⚠️  TEST LAYER VALIDATION: #{message}")
  end
end
