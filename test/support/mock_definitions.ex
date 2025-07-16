# Define mocks at the root level to avoid module nesting issues
if Mix.env() == :test do
  Application.ensure_all_started(:mox)

  # Define the mocks
  Mox.defmock(Test.PubSubMock, for: WandererApp.Test.PubSub)
  Mox.defmock(Test.LoggerMock, for: WandererApp.Test.Logger)
  Mox.defmock(Test.DDRTMock, for: WandererApp.Test.DDRT)

  # Define mock behaviours for testing
  defmodule WandererApp.Cache.MockBehaviour do
    @callback lookup!(binary()) :: any()
    @callback insert(binary(), any(), keyword()) :: any()
  end

  defmodule WandererApp.MapRepo.MockBehaviour do
    @callback get(binary(), list()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.MapConnectionRepo.MockBehaviour do
    @callback get_by_map(binary()) :: {:ok, list()} | {:error, any()}
    @callback get_by_id(binary(), binary()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.Map.MockBehaviour do
    @callback find_connection(binary(), integer(), integer()) ::
                {:ok, map() | nil} | {:error, any()}
  end

  defmodule WandererApp.MapCharacterSettingsRepo.MockBehaviour do
    @callback get_all_by_map(binary()) :: {:ok, list()} | {:error, any()}
  end

  defmodule WandererApp.Character.MockBehaviour do
    @callback get_character(binary()) :: {:ok, map()} | {:error, any()}
    @callback update_character(binary(), map()) :: any()
  end

  defmodule WandererApp.MapUserSettingsRepo.MockBehaviour do
    @callback get(binary(), binary()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.Character.TrackingUtils.MockBehaviour do
    @callback get_main_character(map(), list(), list()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.CachedInfo.MockBehaviour do
    @callback get_ship_type(integer()) :: {:ok, map()} | {:error, any()}
    @callback get_system_static_info(integer()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.MapSystemRepo.MockBehaviour do
    @callback get_visible_by_map(binary()) :: {:ok, list()} | {:error, any()}
    @callback get_by_map_and_solar_system_id(binary(), integer()) ::
                {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.Map.Server.MockBehaviour do
    @callback add_system(binary(), map(), binary(), binary()) :: any()
    @callback update_system_position(binary(), map()) :: any()
    @callback update_system_status(binary(), map()) :: any()
    @callback update_system_description(binary(), map()) :: any()
    @callback update_system_tag(binary(), map()) :: any()
    @callback update_system_locked(binary(), map()) :: any()
    @callback update_system_labels(binary(), map()) :: any()
    @callback update_system_temporary_name(binary(), map()) :: any()
    @callback delete_systems(binary(), list(), binary(), binary()) :: any()
    @callback update_signatures(binary(), map()) :: any()
    @callback add_connection(binary(), map()) :: any()
    @callback delete_connection(binary(), map()) :: any()
    @callback update_connection_mass_status(binary(), map()) :: any()
    @callback update_connection_ship_size_type(binary(), map()) :: any()
    @callback update_connection_type(binary(), map()) :: any()
  end

  defmodule WandererApp.Map.Operations.MockBehaviour do
    @callback list_systems(binary()) :: list()
  end

  defmodule WandererApp.Api.MapSystemSignature.MockBehaviour do
    @callback by_system_id(binary()) :: {:ok, list()} | {:error, any()}
    @callback by_id(binary()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.Api.MapSystem.MockBehaviour do
    @callback by_id(binary()) :: {:ok, map()} | {:error, any()}
  end

  defmodule WandererApp.Map.Operations.Connections.MockBehaviour do
    @callback upsert_single(map(), map()) :: {:ok, atom()} | {:error, any()}
  end

  defmodule WandererApp.Character.TrackingConfigUtils.MockBehaviour do
    @callback get_active_pool!() :: binary()
    @callback update_active_tracking_pool() :: any()
  end

  defmodule WandererApp.Api.Character.MockBehaviour do
    @callback by_eve_id(binary()) :: {:ok, map()} | {:error, any()}
    @callback create(map()) :: {:ok, map()} | {:error, any()}
    @callback update(map(), map()) :: {:ok, map()} | {:error, any()}
    @callback assign_user!(map(), map()) :: map()
  end

  defmodule WandererApp.Api.User.MockBehaviour do
    @callback by_hash(binary()) :: {:ok, map()} | {:error, any()}
  end

  defmodule Test.TelemetryMock.MockBehaviour do
    @callback execute(list(), map()) :: any()
  end

  defmodule Test.AshMock.MockBehaviour do
    @callback create(any()) :: {:ok, map()} | {:error, any()}
    @callback create!(any()) :: map()
  end

  # Define ESI mock behaviour
  defmodule WandererApp.Esi.MockBehaviour do
    @callback get_character_info(binary()) :: {:ok, map()} | {:error, any()}
    @callback get_character_info(binary(), keyword()) :: {:ok, map()} | {:error, any()}
    @callback get_corporation_info(binary()) :: {:ok, map()} | {:error, any()}
    @callback get_corporation_info(binary(), keyword()) :: {:ok, map()} | {:error, any()}
    @callback get_alliance_info(binary()) :: {:ok, map()} | {:error, any()}
    @callback get_alliance_info(binary(), keyword()) :: {:ok, map()} | {:error, any()}
  end

  # Define all the mocks
  Mox.defmock(Test.CacheMock, for: WandererApp.Cache.MockBehaviour)
  Mox.defmock(Test.MapRepoMock, for: WandererApp.MapRepo.MockBehaviour)
  Mox.defmock(Test.MapConnectionRepoMock, for: WandererApp.MapConnectionRepo.MockBehaviour)
  Mox.defmock(Test.MapMock, for: WandererApp.Map.MockBehaviour)

  Mox.defmock(Test.MapCharacterSettingsRepoMock,
    for: WandererApp.MapCharacterSettingsRepo.MockBehaviour
  )

  Mox.defmock(Test.CharacterMock, for: WandererApp.Character.MockBehaviour)
  Mox.defmock(Test.MapUserSettingsRepoMock, for: WandererApp.MapUserSettingsRepo.MockBehaviour)
  Mox.defmock(Test.TrackingUtilsMock, for: WandererApp.Character.TrackingUtils.MockBehaviour)
  Mox.defmock(WandererApp.CachedInfo.Mock, for: WandererApp.CachedInfo.MockBehaviour)
  Mox.defmock(Test.MapSystemRepoMock, for: WandererApp.MapSystemRepo.MockBehaviour)
  Mox.defmock(Test.MapServerMock, for: WandererApp.Map.Server.MockBehaviour)
  Mox.defmock(Test.OperationsMock, for: WandererApp.Map.Operations.MockBehaviour)
  Mox.defmock(Test.MapSystemSignatureMock, for: WandererApp.Api.MapSystemSignature.MockBehaviour)
  Mox.defmock(Test.MapSystemMock, for: WandererApp.Api.MapSystem.MockBehaviour)
  Mox.defmock(Test.ConnectionsMock, for: WandererApp.Map.Operations.Connections.MockBehaviour)

  Mox.defmock(Test.TrackingConfigUtilsMock,
    for: WandererApp.Character.TrackingConfigUtils.MockBehaviour
  )

  Mox.defmock(Test.CharacterApiMock, for: WandererApp.Api.Character.MockBehaviour)
  Mox.defmock(Test.UserApiMock, for: WandererApp.Api.User.MockBehaviour)
  Mox.defmock(Test.TelemetryMock, for: Test.TelemetryMock.MockBehaviour)
  Mox.defmock(Test.AshMock, for: Test.AshMock.MockBehaviour)
  Mox.defmock(WandererApp.Esi.Mock, for: WandererApp.Esi.MockBehaviour)
end
