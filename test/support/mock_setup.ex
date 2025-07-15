defmodule WandererApp.Support.MockSetup do
  @moduledoc """
  Centralized mock setup and configuration for tests.

  This module provides:
  - Default stub behaviors for common mocks
  - Consistent mock configuration across tests
  - Helper functions for mock setup
  """

  import Mox

  defmacro __using__(_) do
    quote do
      import Mox
      import WandererApp.Support.MockSetup

      setup :verify_on_exit!
      setup :setup_default_mocks
    end
  end

  def setup_default_mocks(_context) do
    # Default ESI API stubs
    WandererApp.CachedInfo.Mock
    |> stub(:get_server_status, fn ->
      {:ok, %{"players" => 12_345, "server_version" => "1.0.0"}}
    end)
    |> stub(:get_character_info, fn character_id ->
      {:ok,
       %{
         "character_id" => character_id,
         "name" => "Test Character #{character_id}",
         "corporation_id" => 1_000_001,
         "alliance_id" => 500_001
       }}
    end)
    |> stub(:get_character_location, fn _character_id ->
      {:ok,
       %{
         "solar_system_id" => 30_000_142,
         "station_id" => 60_003_760
       }}
    end)
    |> stub(:get_character_ship, fn _character_id ->
      {:ok,
       %{
         "ship_item_id" => 1_000_000_016_991,
         "ship_name" => "Test Ship",
         "ship_type_id" => 670
       }}
    end)

    # Default external service stubs
    WandererApp.ExternalServices.Mock
    |> stub(:send_webhook, fn _url, _payload, _headers ->
      {:ok, %{status: 200, body: "OK"}}
    end)
    |> stub(:validate_license, fn _license_key ->
      {:ok, %{valid: true, expires_at: DateTime.utc_now() |> DateTime.add(30, :day)}}
    end)

    # Default telemetry stubs (non-critical)
    WandererApp.Telemetry.Mock
    |> stub(:track_event, fn _event, _properties -> :ok end)
    |> stub(:track_timing, fn _event, _duration -> :ok end)
    |> stub(:track_error, fn _error, _context -> :ok end)

    # Default cache stubs
    WandererApp.Cache.Mock
    |> stub(:get, fn _key -> {:ok, nil} end)
    |> stub(:put, fn _key, _value -> :ok end)
    |> stub(:delete, fn _key -> :ok end)

    :ok
  end

  @doc """
  Sets up ESI API mock with specific responses for a character.
  """
  def setup_character_esi_mock(character_id, overrides \\ %{}) do
    default_character_info = %{
      "character_id" => character_id,
      "name" => "Test Character #{character_id}",
      "corporation_id" => 1_000_001,
      "alliance_id" => 500_001
    }

    default_location = %{
      "solar_system_id" => 30_000_142,
      "station_id" => 60_003_760
    }

    default_ship = %{
      "ship_item_id" => 1_000_000_016_991,
      "ship_name" => "Test Ship",
      "ship_type_id" => 670
    }

    character_info = Map.merge(default_character_info, overrides[:character_info] || %{})
    location = Map.merge(default_location, overrides[:location] || %{})
    ship = Map.merge(default_ship, overrides[:ship] || %{})

    WandererApp.CachedInfo.Mock
    |> stub(:get_character_info, fn ^character_id -> {:ok, character_info} end)
    |> stub(:get_character_location, fn ^character_id -> {:ok, location} end)
    |> stub(:get_character_ship, fn ^character_id -> {:ok, ship} end)
  end

  @doc """
  Sets up webhook mock with specific expectations.
  """
  def setup_webhook_mock(url, expected_payload, response \\ %{status: 200, body: "OK"}) do
    WandererApp.ExternalServices.Mock
    |> stub(:send_webhook, fn ^url, ^expected_payload, _headers ->
      {:ok, response}
    end)
  end

  @doc """
  Sets up cache mock with specific key-value pairs.
  """
  def setup_cache_mock(cache_data) when is_map(cache_data) do
    Enum.each(cache_data, fn {key, value} ->
      WandererApp.Cache.Mock
      |> stub(:get, fn ^key -> {:ok, value} end)
    end)
  end

  @doc """
  Sets up error scenarios for testing error handling.
  """
  def setup_error_scenarios(service, error_type \\ :timeout) do
    error_response =
      case error_type do
        :timeout -> {:error, :timeout}
        :network -> {:error, :network_error}
        :auth -> {:error, :unauthorized}
        :not_found -> {:error, :not_found}
        :server_error -> {:error, :server_error}
      end

    case service do
      :esi ->
        WandererApp.CachedInfo.Mock
        |> stub(:get_character_info, fn _id -> error_response end)
        |> stub(:get_character_location, fn _id -> error_response end)
        |> stub(:get_character_ship, fn _id -> error_response end)

      :webhooks ->
        WandererApp.ExternalServices.Mock
        |> stub(:send_webhook, fn _url, _payload, _headers -> error_response end)

      :cache ->
        WandererApp.Cache.Mock
        |> stub(:get, fn _key -> error_response end)
        |> stub(:put, fn _key, _value -> error_response end)
    end
  end

  @doc """
  Verifies that no unexpected calls were made to mocks.
  """
  def verify_no_unexpected_calls do
    # This is automatically handled by Mox.verify_on_exit!
    # But we can add additional verification logic here if needed
    :ok
  end

  @doc """
  Resets all mocks to their default state.
  """
  def reset_mocks do
    # Reset all mocks to their default stub behaviors
    setup_default_mocks(%{})
  end
end
