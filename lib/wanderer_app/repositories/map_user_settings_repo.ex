defmodule WandererApp.MapUserSettingsRepo do
  use WandererApp, :repository

  @default_form_data %{"select_on_spash" => "false"}

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

  def to_form_data(nil), do: {:ok, @default_form_data}
  def to_form_data(%{settings: settings} = _user_settings), do: {:ok, Jason.decode!(settings)}

  def to_form_data!(user_settings) do
    {:ok, data} = to_form_data(user_settings)
    data
  end
end