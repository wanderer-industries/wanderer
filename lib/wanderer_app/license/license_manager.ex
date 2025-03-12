defmodule WandererApp.License.LicenseManager do
  @moduledoc """
  Manages bot licenses, including creation, validation, and expiration.

  This module provides functions for:
  - Creating licenses for maps with active subscriptions
  - Validating license keys
  - Checking license expiration
  - Generating unique license keys
  """

  require Logger

  alias WandererApp.Api.License
  alias WandererApp.Api.Map
  alias WandererApp.Map.SubscriptionManager
  alias WandererApp.License.LicenseManagerClient

  @doc """
  Creates a new license for a map if it has an active subscription.
  Returns {:ok, license} if successful, {:error, reason} otherwise.
  """
  def create_license_for_map(map_id) do
    with {:ok, map} <- Map.by_id(map_id),
         {:ok, true} <- WandererApp.Map.is_subscription_active?(map_id),
         {:ok, subscription} <- SubscriptionManager.get_active_map_subscription(map_id) do
      # Create a license in the local database

      # Create a license in the external License Manager service
      license_params = %{
        "name" => "#{map.name} License",
        "description" => "License for #{map.name} map",
        "is_valid" => true,
        "valid_to" => format_date(subscription.active_till),
        "link" => generate_map_link(map.slug),
        "contact_email" => get_map_owner_email(map)
      }

      case LicenseManagerClient.create_license(license_params) do
        {:ok, external_license} ->
          License.create(%{
            map_id: map_id,
            lm_id: external_license["id"],
            license_key: external_license["key"],
            is_valid: true,
            expire_at: subscription.active_till
          })

        {:error, reason} ->
          # Log the error but don't fail the operation
          Logger.error("Failed to create license in external service: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:ok, false} -> {:error, :no_active_subscription}
      error -> error
    end
  end

  @doc """
  Validates a license key.
  Returns {:ok, license} if valid, {:error, reason} otherwise.
  """
  def validate_license(license_key) do
    # First check in our local database
    case License.by_key(license_key) do
      {:ok, license} ->
        case LicenseManagerClient.validate_license(license_key) do
          {:ok, %{"license_valid" => is_valid}} ->
            {:ok, %{license | is_valid: is_valid}}

          {:error, reason} ->
            # External validation failed, but we'll still consider it valid
            # if it's valid in our local database
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Invalidates a license.
  """
  def invalidate_license(license_id) do
    with {:ok, license} <- License.by_id(license_id) do
      # Try to invalidate in external service
      case LicenseManagerClient.update_license(license.lm_id, %{
             "is_valid" => false
           }) do
        {:ok, _} ->
          License.invalidate(license)

        error ->
          error
      end
    end
  end

  @doc """
  Updates the expiration date of a license.
  """
  def update_expiration(license_id, expire_at) do
    with {:ok, license} <- License.by_id(license_id) do
      # Update in local database

      # Try to update in external service
      LicenseManagerClient.update_license(license.lm_id, %{
        "valid_to" => format_date(expire_at)
      })
      |> case do
        {:ok, _license} ->
          License.update_expire_at(license, %{expire_at: expire_at})

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @doc """
  Gets a license by map ID.
  Returns {:ok, license} if found, {:error, reason} otherwise.
  """
  def get_license_by_map_id(map_id) do
    case License.by_map_id(%{map_id: map_id}) do
      {:ok, [license | _]} ->
        {:ok, license}

      {:ok, []} ->
        {:error, :license_not_found}

      error ->
        error
    end
  end

  @doc """
  Updates a license's expiration date based on the map's subscription.
  """
  def update_license_expiration_from_subscription(map_id) do
    with {:ok, license} <- get_license_by_map_id(map_id),
         {:ok, subscription} <- SubscriptionManager.get_active_map_subscription(map_id) do
      update_expiration(license.id, subscription.active_till)
    end
  end

  @doc """
  Checks if a license is expired.
  """
  defp expired?(license) do
    case license.expire_at do
      nil -> false
      expire_at -> DateTime.compare(expire_at, DateTime.utc_now()) == :lt
    end
  end

  @doc """
  Generates a random string of specified length.
  """
  defp generate_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode16(case: :upper)
    |> binary_part(0, length)
  end

  @doc """
  Formats a datetime as YYYY-MM-DD.
  """
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end

  @doc """
  Generates a link to the map.
  """
  defp generate_map_link(map_slug) do
    base_url = Application.get_env(:wanderer_app, :web_app_url)
    "#{base_url}/#{map_slug}"
  end

  @doc """
  Gets the map owner's data.
  """
  defp get_map_owner_email(map) do
    {:ok, %{owner: owner}} = map |> Ash.load([:owner])
    "#{owner.name}(#{owner.eve_id})"
  end
end
