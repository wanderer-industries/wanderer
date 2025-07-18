defmodule WandererApp.MapTestHelpers do
  @moduledoc """
  Shared helper functions for map-related tests.
  """

  @doc """
  Helper function to expect a map server error response.
  This function is used across multiple test files to handle
  map server errors consistently in unit test environments.
  """
  def expect_map_server_error(test_fun) do
    try do
      test_fun.()
    catch
      "Map server not started" ->
        # Expected in unit test environment - map servers aren't started
        :ok
    end
  end
end
