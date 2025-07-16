defmodule WandererApp.Repo.Migrations.FixWebhookSecretColumn do
  @moduledoc """
  Fix webhook secret column to use plain text instead of encrypted binary.

  This migration updates the webhook subscription table to use a plain text 
  secret column instead of the encrypted binary column to avoid issues with 
  AshCloak encryption in testing environments.
  """

  use Ecto.Migration

  def up do
    # Add the new secret column as text
    alter table(:map_webhook_subscriptions_v1) do
      add :secret, :text, null: false, default: ""
    end

    # Remove the encrypted_secret column
    alter table(:map_webhook_subscriptions_v1) do
      remove :encrypted_secret
    end
  end

  def down do
    # Add back the encrypted_secret column
    alter table(:map_webhook_subscriptions_v1) do
      add :encrypted_secret, :binary, null: false
    end

    # Remove the secret column
    alter table(:map_webhook_subscriptions_v1) do
      remove :secret
    end
  end
end
