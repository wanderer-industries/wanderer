defmodule WandererApp.MapCharacterSettingsRepo do
  use WandererApp, :repository

  def create(settings),
    do: WandererApp.Api.MapCharacterSettings.create(settings)
end
