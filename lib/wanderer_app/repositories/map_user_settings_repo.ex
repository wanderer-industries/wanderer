defmodule WandererApp.MapUserSettingsRepo do
  use WandererApp, :repository
  
  require Logger

  @default_form_data %{
    "select_on_spash" => false,
    "link_signature_on_splash" => false,
    "delete_connection_with_sigs" => false,
    "primary_character_id" => nil
  }

  def get(map_id, user_id) do
    map_id
    |> WandererApp.Api.MapUserSettings.by_user_id(user_id)
    |> case do
      {:ok, settings} ->
        {:ok, settings}

      _ ->
        {:ok, nil}
    end
  end

  def get!(map_id, user_id) do
    WandererApp.Api.MapUserSettings.by_user_id(map_id, user_id)
    |> case do
      {:ok, user_settings} -> user_settings
      _ -> nil
    end
  end

  def create_or_update(map_id, user_id, nil) do
    create_or_update(map_id, user_id, @default_form_data |> Jason.encode!())
  end

  def create_or_update(map_id, user_id, settings) do
    get!(map_id, user_id)
    |> case do
      user_settings when not is_nil(user_settings) ->
        user_settings
        |> WandererApp.Api.MapUserSettings.update_settings(%{settings: settings})

      _ ->
        WandererApp.Api.MapUserSettings.create(%{
          map_id: map_id,
          user_id: user_id,
          settings: settings
        })
    end
  end

  def get_hubs(map_id, user_id) do
    case WandererApp.MapUserSettingsRepo.get(map_id, user_id) do
      {:ok, user_settings} when not is_nil(user_settings) ->
        {:ok, Map.get(user_settings, :hubs, [])}

      _ ->
        {:ok, []}
    end
  end

  def update_hubs(map_id, user_id, hubs) do
    get!(map_id, user_id)
    |> case do
      user_settings when not is_nil(user_settings) ->
        user_settings
        |> WandererApp.Api.MapUserSettings.update_hubs(%{hubs: hubs})

      _ ->
        WandererApp.Api.MapUserSettings.create!(%{
          map_id: map_id,
          user_id: user_id,
          settings: @default_form_data |> Jason.encode!()
        })
        |> WandererApp.Api.MapUserSettings.update_hubs(%{hubs: hubs})
    end
  end

  def to_form_data(nil), do: {:ok, @default_form_data}
  def to_form_data(%{settings: settings} = _user_settings), do: {:ok, Jason.decode!(settings)}

  def to_form_data!(user_settings) do
    {:ok, data} = to_form_data(user_settings)
    data
  end

  def get_boolean_setting(settings, key, default \\ false) do
    settings
    |> Map.get(key, default)
    |> to_boolean()
  end

  def to_boolean(value) when is_binary(value), do: value |> String.to_existing_atom()
  def to_boolean(value) when is_boolean(value), do: value

  @doc """
  Gets all map user settings where the specified character_eve_id is marked as ready.
  Returns {:ok, [settings]} or {:error, reason}
  """
  def get_settings_with_ready_character(character_eve_id) when is_binary(character_eve_id) and character_eve_id != "" do
    # Use raw Ecto query since Ash may not support array operations well
    import Ecto.Query

    query =
      from(settings in "map_user_settings_v1",
        where: fragment("? = ANY(?)", ^character_eve_id, settings.ready_characters),
        select: %{
          id: settings.id,
          map_id: settings.map_id,
          user_id: settings.user_id,
          ready_characters: settings.ready_characters,
          settings: settings.settings,
          main_character_eve_id: settings.main_character_eve_id,
          following_character_eve_id: settings.following_character_eve_id,
          hubs: settings.hubs
        }
      )

    try do
      case WandererApp.Repo.all(query) do
        results when is_list(results) ->
          # Convert to Ash structs
          ash_results =
            Enum.map(results, fn result ->
              struct(WandererApp.Api.MapUserSettings, result)
            end)

          {:ok, ash_results}

        error ->
          Logger.error("Unexpected result from Repo.all in get_settings_with_ready_character: #{inspect(error)}")
          {:error, :unexpected_result}
      end
    rescue
      error ->
        Logger.error("Database error in get_settings_with_ready_character: #{inspect(error)}")
        {:error, error}
    end
  end

  def get_settings_with_ready_character(character_eve_id) do
    Logger.error("Invalid character_eve_id provided: #{inspect(character_eve_id)}")
    {:error, :invalid_character_eve_id}
  end
end
