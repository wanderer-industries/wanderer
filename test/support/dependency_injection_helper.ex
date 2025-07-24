defmodule WandererApp.DependencyInjectionHelper do
  @moduledoc """
  Helper functions for enabling dependency injection in specific tests.
  """

  @doc """
  Enables dependency injection for Owner operations and sets up the required mock configurations.
  """
  def enable_owner_dependency_injection do
    # Enable dependency injection for the Owner module
    Application.put_env(:wanderer_app, :enable_dependency_injection_owner, true)

    # Configure the mock implementations
    Application.put_env(:wanderer_app, :cache_impl, Test.CacheMock)
    Application.put_env(:wanderer_app, :map_repo_impl, Test.MapRepoMock)

    Application.put_env(
      :wanderer_app,
      :map_character_settings_repo_impl,
      Test.MapCharacterSettingsRepoMock
    )

    Application.put_env(:wanderer_app, :map_user_settings_repo_impl, Test.MapUserSettingsRepoMock)
    Application.put_env(:wanderer_app, :character_impl, Test.CharacterMock)
    Application.put_env(:wanderer_app, :tracking_utils_impl, Test.TrackingUtilsMock)
  end

  @doc """
  Enables dependency injection for Systems operations and sets up the required mock configurations.
  """
  def enable_systems_dependency_injection do
    # Enable dependency injection for the Systems module
    Application.put_env(:wanderer_app, :enable_dependency_injection_systems, true)

    # Configure the mock implementations
    Application.put_env(:wanderer_app, :map_system_repo_impl, Test.MapSystemRepoMock)
    Application.put_env(:wanderer_app, :map_server_impl, Test.MapServerMock)
    Application.put_env(:wanderer_app, :connections_impl, Test.ConnectionsMock)
    Application.put_env(:wanderer_app, :logger, Test.LoggerMock)
  end

  @doc """
  Enables dependency injection for Signatures operations and sets up the required mock configurations.
  """
  def enable_signatures_dependency_injection do
    # Enable dependency injection for the Signatures module
    Application.put_env(:wanderer_app, :enable_dependency_injection_signatures, true)

    # Configure the mock implementations
    Application.put_env(:wanderer_app, :logger, Test.LoggerMock)
    Application.put_env(:wanderer_app, :operations_impl, Test.OperationsMock)
    Application.put_env(:wanderer_app, :map_system_impl, Test.MapSystemMock)
    Application.put_env(:wanderer_app, :map_system_signature_impl, Test.MapSystemSignatureMock)
    Application.put_env(:wanderer_app, :map_server_impl, Test.MapServerMock)
  end

  @doc """
  Enables dependency injection for Auth controller and sets up the required mock configurations.
  """
  def enable_auth_dependency_injection do
    # Enable dependency injection for the Auth controller
    Application.put_env(:wanderer_app, :enable_dependency_injection_auth, true)

    # Configure the mock implementations
    Application.put_env(:wanderer_app, :tracking_config_utils_impl, Test.TrackingConfigUtilsMock)
    Application.put_env(:wanderer_app, :character_api_impl, Test.CharacterApiMock)
    Application.put_env(:wanderer_app, :character_impl, Test.CharacterMock)
    Application.put_env(:wanderer_app, :user_api_impl, Test.UserApiMock)
    Application.put_env(:wanderer_app, :telemetry_impl, Test.TelemetryMock)
    Application.put_env(:wanderer_app, :ash_impl, Test.AshMock)
  end

  @doc """
  Disables all dependency injection configurations, restoring default behavior.
  """
  def disable_dependency_injection do
    Application.put_env(:wanderer_app, :enable_dependency_injection_owner, false)
    Application.put_env(:wanderer_app, :enable_dependency_injection_systems, false)
    Application.put_env(:wanderer_app, :enable_dependency_injection_signatures, false)
    Application.put_env(:wanderer_app, :enable_dependency_injection_auth, false)
  end
end
