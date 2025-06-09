defmodule WandererApp.Api do
  @moduledoc false

  use Ash.Domain

  resources do
    resource WandererApp.Api.AccessList
    resource WandererApp.Api.AccessListMember
    resource WandererApp.Api.Character
    resource WandererApp.Api.Map
    resource WandererApp.Api.MapAccessList
    resource WandererApp.Api.MapSolarSystem
    resource WandererApp.Api.MapSolarSystemJumps
    resource WandererApp.Api.MapChainPassages
    resource WandererApp.Api.MapConnection
    resource WandererApp.Api.MapState
    resource WandererApp.Api.MapSystem
    resource WandererApp.Api.MapSystemComment
    resource WandererApp.Api.MapSystemSignature
    resource WandererApp.Api.MapSystemStructure
    resource WandererApp.Api.MapCharacterSettings
    resource WandererApp.Api.MapSubscription
    resource WandererApp.Api.MapTransaction
    resource WandererApp.Api.MapUserSettings
    resource WandererApp.Api.User
    resource WandererApp.Api.ShipTypeInfo
    resource WandererApp.Api.UserActivity
    resource WandererApp.Api.UserTransaction
    resource WandererApp.Api.CorpWalletTransaction
    resource WandererApp.Api.License
    resource WandererApp.Api.MapPing
    resource WandererApp.Api.MapInvite
  end
end
