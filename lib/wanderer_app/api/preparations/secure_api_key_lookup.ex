defmodule WandererApp.Api.Preparations.SecureApiKeyLookup do
  @moduledoc """
  Preparation that performs secure API key lookup using constant-time comparison.

  This preparation:
  1. Queries for the map with the given API key using database index
  2. Performs constant-time comparison to verify the key matches
  3. Returns the map only if the secure comparison passes

  The constant-time comparison prevents timing attacks where an attacker
  could deduce information about valid API keys by measuring response times.
  """

  use Ash.Resource.Preparation
  require Ash.Query

  @dummy_key "dummy_key_for_timing_consistency_00000000"

  def prepare(query, _params, _context) do
    api_key = Ash.Query.get_argument(query, :api_key)

    if is_nil(api_key) or api_key == "" do
      # Return empty result for invalid input
      Ash.Query.filter(query, expr(false))
    else
      # First, do the database lookup using the index
      # Then apply constant-time comparison in after_action
      query
      |> Ash.Query.filter(expr(public_api_key == ^api_key))
      |> Ash.Query.after_action(fn _query, results ->
        verify_results_with_secure_compare(results, api_key)
      end)
    end
  end

  defp verify_results_with_secure_compare(results, provided_key) do
    case results do
      [map] ->
        # Map found - verify with constant-time comparison
        stored_key = map.public_api_key || @dummy_key

        if Plug.Crypto.secure_compare(stored_key, provided_key) do
          {:ok, [map]}
        else
          # Keys don't match (shouldn't happen if DB returned it, but safety check)
          {:ok, []}
        end

      [] ->
        # No map found - still do a comparison to maintain consistent timing
        # This prevents timing attacks from distinguishing "not found" from "found but wrong"
        _result = Plug.Crypto.secure_compare(@dummy_key, provided_key)
        {:ok, []}

      _multiple ->
        # Multiple results - shouldn't happen with unique constraint
        # Do comparison for timing consistency and return error
        _result = Plug.Crypto.secure_compare(@dummy_key, provided_key)
        {:ok, []}
    end
  end
end
