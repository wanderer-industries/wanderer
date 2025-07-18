defmodule WandererAppWeb.MapWebhooksAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.MapWebhookSubscription
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

  require Logger

  # -----------------------------------------------------------------
  # V1 API Actions (for compatibility with versioned API router)
  # -----------------------------------------------------------------

  def index_v1(conn, params) do
    # Convert map_id to map_identifier for existing implementation
    updated_params =
      case params do
        %{"map_id" => map_id} -> Map.put(params, "map_identifier", map_id)
        _ -> params
      end

    index(conn, updated_params)
  end

  def show_v1(conn, params) do
    # Convert map_id to map_identifier for existing implementation
    updated_params =
      case params do
        %{"map_id" => map_id} -> Map.put(params, "map_identifier", map_id)
        _ -> params
      end

    show(conn, updated_params)
  end

  def create_v1(conn, params) do
    # Convert map_id to map_identifier for existing implementation
    updated_params =
      case params do
        %{"map_id" => map_id} -> Map.put(params, "map_identifier", map_id)
        _ -> params
      end

    create(conn, updated_params)
  end

  def update_v1(conn, params) do
    # Convert map_id to map_identifier for existing implementation
    updated_params =
      case params do
        %{"map_id" => map_id} -> Map.put(params, "map_identifier", map_id)
        _ -> params
      end

    update(conn, updated_params)
  end

  def delete_v1(conn, params) do
    # Convert map_id to map_identifier for existing implementation
    updated_params =
      case params do
        %{"map_id" => map_id} -> Map.put(params, "map_identifier", map_id)
        _ -> params
      end

    delete(conn, updated_params)
  end

  # -----------------------------------------------------------------
  # Schema Definitions
  # -----------------------------------------------------------------

  @webhook_subscription_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string, description: "Webhook subscription UUID"},
      map_id: %OpenApiSpex.Schema{type: :string, description: "Map UUID"},
      url: %OpenApiSpex.Schema{
        type: :string,
        description: "HTTPS webhook endpoint URL",
        example: "https://example.com/webhook"
      },
      events: %OpenApiSpex.Schema{
        type: :array,
        items: %OpenApiSpex.Schema{type: :string},
        description: "Array of event types to subscribe to, or ['*'] for all",
        example: ["add_system", "map_kill", "*"]
      },
      active: %OpenApiSpex.Schema{type: :boolean, description: "Whether webhook is active"},
      last_delivery_at: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Last successful delivery timestamp",
        nullable: true
      },
      last_error: %OpenApiSpex.Schema{
        type: :string,
        description: "Last error message if delivery failed",
        nullable: true
      },
      consecutive_failures: %OpenApiSpex.Schema{
        type: :integer,
        description: "Number of consecutive delivery failures"
      },
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: [:id, :map_id, :url, :events, :active, :consecutive_failures],
    example: %{
      id: "550e8400-e29b-41d4-a716-446655440000",
      map_id: "550e8400-e29b-41d4-a716-446655440001",
      url: "https://example.com/wanderer-webhook",
      events: ["add_system", "map_kill"],
      active: true,
      last_delivery_at: "2025-06-21T12:34:56Z",
      last_error: nil,
      consecutive_failures: 0,
      inserted_at: "2025-06-21T10:00:00Z",
      updated_at: "2025-06-21T12:34:56Z"
    }
  }

  @webhook_create_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      url: %OpenApiSpex.Schema{
        type: :string,
        description: "HTTPS webhook endpoint URL (max 2000 characters)",
        example: "https://example.com/wanderer-webhook"
      },
      events: %OpenApiSpex.Schema{
        type: :array,
        items: %OpenApiSpex.Schema{type: :string},
        description: "Array of event types to subscribe to, or ['*'] for all events",
        example: ["add_system", "map_kill"]
      },
      active: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Whether webhook should be active (default: true)",
        default: true
      }
    },
    required: [:url, :events],
    example: %{
      url: "https://example.com/wanderer-webhook",
      events: ["add_system", "signatures_updated", "map_kill"],
      active: true
    }
  }

  @webhook_update_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      url: %OpenApiSpex.Schema{
        type: :string,
        description: "HTTPS webhook endpoint URL (max 2000 characters)"
      },
      events: %OpenApiSpex.Schema{
        type: :array,
        items: %OpenApiSpex.Schema{type: :string},
        description: "Array of event types to subscribe to, or ['*'] for all events"
      },
      active: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Whether webhook should be active"
      }
    },
    example: %{
      events: ["*"],
      active: false
    }
  }

  @webhook_secret_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      secret: %OpenApiSpex.Schema{
        type: :string,
        description: "New webhook secret for HMAC signature verification"
      }
    },
    required: [:secret],
    example: %{
      secret: "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz="
    }
  }

  @webhooks_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                              type: :array,
                              items: @webhook_subscription_schema
                            })

  @webhook_response_schema ApiSchemas.data_wrapper(@webhook_subscription_schema)
  @secret_response_schema ApiSchemas.data_wrapper(@webhook_secret_response_schema)

  # -----------------------------------------------------------------
  # OpenApiSpex Operations
  # -----------------------------------------------------------------

  operation(:index,
    summary: "List webhook subscriptions for a map",
    description: "Retrieves all webhook subscriptions configured for the specified map.",
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ]
    ],
    responses: %{
      200 => {"Success", "application/json", @webhooks_response_schema},
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Map not found"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  operation(:show,
    summary: "Get a specific webhook subscription",
    description: "Retrieves details of a specific webhook subscription.",
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ],
      id: [
        in: :path,
        description: "Webhook subscription UUID",
        type: :string,
        required: true
      ]
    ],
    responses: %{
      200 => {"Success", "application/json", @webhook_response_schema},
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Webhook not found"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  operation(:create,
    summary: "Create a new webhook subscription",
    description: """
    Creates a new webhook subscription for the map. The webhook will receive HTTP POST
    requests for the specified event types. A secret is automatically generated for
    HMAC signature verification.
    """,
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ]
    ],
    request_body: {"Webhook subscription data", "application/json", @webhook_create_schema},
    responses: %{
      201 => {"Created", "application/json", @webhook_response_schema},
      400 => ResponseSchemas.bad_request("Invalid webhook data"),
      401 => ResponseSchemas.bad_request("Unauthorized"),
      409 => ResponseSchemas.bad_request("Webhook URL already exists for this map"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  operation(:update,
    summary: "Update a webhook subscription",
    description: "Updates an existing webhook subscription. Partial updates are supported.",
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ],
      id: [
        in: :path,
        description: "Webhook subscription UUID",
        type: :string,
        required: true
      ]
    ],
    request_body: {"Webhook update data", "application/json", @webhook_update_schema},
    responses: %{
      200 => {"Updated", "application/json", @webhook_response_schema},
      400 => ResponseSchemas.bad_request("Invalid webhook data"),
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Webhook not found"),
      409 => ResponseSchemas.bad_request("Webhook URL already exists for this map"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  operation(:delete,
    summary: "Delete a webhook subscription",
    description: "Permanently deletes a webhook subscription.",
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ],
      id: [
        in: :path,
        description: "Webhook subscription UUID",
        type: :string,
        required: true
      ]
    ],
    responses: %{
      204 => {"Deleted", "application/json", nil},
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Webhook not found"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  operation(:rotate_secret,
    summary: "Rotate webhook secret",
    description: """
    Generates a new secret for the webhook subscription. The old secret will be
    invalidated immediately. Update your webhook endpoint to use the new secret
    for HMAC signature verification.
    """,
    tags: ["Webhook Management"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ],
      map_webhooks_api_id: [
        in: :path,
        description: "Webhook subscription UUID",
        type: :string,
        required: true
      ]
    ],
    responses: %{
      200 => {"Secret rotated", "application/json", @secret_response_schema},
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Webhook not found"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  # -----------------------------------------------------------------
  # Controller Actions
  # -----------------------------------------------------------------

  def index(conn, %{"map_identifier" => map_identifier}) do
    with {:ok, map} <- get_map(conn, map_identifier) do
      webhooks = MapWebhookSubscription.by_map!(map.id)

      json_webhooks = Enum.map(webhooks, &webhook_to_json/1)
      json(conn, %{data: json_webhooks})
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, reason} ->
        Logger.error("Failed to list webhooks: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  def show(conn, %{"map_identifier" => map_identifier, "id" => webhook_id}) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, webhook} <- get_webhook(webhook_id, map.id) do
      json(conn, %{data: webhook_to_json(webhook)})
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :webhook_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Webhook not found"})

      {:error, reason} ->
        Logger.error("Failed to get webhook: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  def create(conn, %{"map_identifier" => map_identifier} = params) do
    # Check if webhooks are enabled
    if not Application.get_env(:wanderer_app, :external_events, [])[:webhooks_enabled] do
      conn
      |> put_status(:service_unavailable)
      |> json(%{error: "Webhooks are disabled on this server"})
    else
      do_create_webhook(conn, map_identifier, params)
    end
  end

  defp do_create_webhook(conn, map_identifier, params) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, webhook_params} <- validate_create_params(params, map.id) do
      case MapWebhookSubscription.create(webhook_params) do
        {:ok, webhook} ->
          conn
          |> put_status(:created)
          |> json(%{data: webhook_to_json(webhook)})

        {:error, %Ash.Error.Invalid{errors: errors}} ->
          error_messages =
            Enum.map(errors, fn error ->
              case error do
                %{message: message} ->
                  message

                %Ash.Error.Changes.NoSuchAttribute{attribute: attr} ->
                  "Invalid attribute: #{attr}"

                _ ->
                  inspect(error)
              end
            end)

          conn
          |> put_status(:bad_request)
          |> json(%{error: "Validation failed", details: error_messages})

        {:error, reason} ->
          Logger.error("Failed to create webhook: #{inspect(reason)}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Internal server error"})
      end
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :invalid_params} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid webhook parameters"})

      {:error, reason} ->
        Logger.error("Failed to create webhook: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  def update(conn, %{"map_identifier" => map_identifier, "id" => webhook_id} = params) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, webhook} <- get_webhook(webhook_id, map.id),
         {:ok, update_params} <- validate_update_params(params) do
      case MapWebhookSubscription.update(webhook, update_params) do
        {:ok, updated_webhook} ->
          json(conn, %{data: webhook_to_json(updated_webhook)})

        {:error, %Ash.Error.Invalid{errors: errors}} ->
          error_messages =
            Enum.map(errors, fn error ->
              case error do
                %{message: message} ->
                  message

                %Ash.Error.Changes.NoSuchAttribute{attribute: attr} ->
                  "Invalid attribute: #{attr}"

                _ ->
                  inspect(error)
              end
            end)

          conn
          |> put_status(:bad_request)
          |> json(%{error: "Validation failed", details: error_messages})

        {:error, reason} ->
          Logger.error("Failed to update webhook: #{inspect(reason)}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Internal server error"})
      end
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :webhook_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Webhook not found"})

      {:error, :invalid_params} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid webhook parameters"})

      {:error, reason} ->
        Logger.error("Failed to update webhook: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  def delete(conn, %{"map_identifier" => map_identifier, "id" => webhook_id}) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, webhook} <- get_webhook(webhook_id, map.id) do
      case MapWebhookSubscription.destroy(webhook) do
        :ok ->
          conn |> put_status(:no_content)

        {:error, reason} ->
          Logger.error("Failed to delete webhook: #{inspect(reason)}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Internal server error"})
      end
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :webhook_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Webhook not found"})

      {:error, reason} ->
        Logger.error("Failed to delete webhook: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  def rotate_secret(conn, %{
        "map_identifier" => map_identifier,
        "map_webhooks_api_id" => webhook_id
      }) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, webhook} <- get_webhook(webhook_id, map.id) do
      case MapWebhookSubscription.rotate_secret(webhook) do
        {:ok, updated_webhook} ->
          # Return the new secret (this is the only time it's exposed)
          json(conn, %{data: %{secret: updated_webhook.secret}})

        {:error, reason} ->
          Logger.error("Failed to rotate webhook secret: #{inspect(reason)}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Internal server error"})
      end
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :webhook_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Webhook not found"})

      {:error, reason} ->
        Logger.error("Failed to rotate webhook secret: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  # -----------------------------------------------------------------
  # Private Functions
  # -----------------------------------------------------------------

  defp get_map(conn, map_identifier) do
    # The map should already be loaded by the CheckMapApiKey plug
    case conn.assigns[:map] do
      nil -> {:error, :map_not_found}
      map -> {:ok, map}
    end
  end

  defp get_webhook(webhook_id, map_id) do
    try do
      case MapWebhookSubscription.by_id(webhook_id) do
        nil ->
          {:error, :webhook_not_found}

        {:ok, webhook} ->
          if webhook.map_id == map_id do
            {:ok, webhook}
          else
            {:error, :webhook_not_found}
          end

        {:error, _error} ->
          {:error, :webhook_not_found}

        webhook ->
          if webhook.map_id == map_id do
            {:ok, webhook}
          else
            {:error, :webhook_not_found}
          end
      end
    rescue
      # Only catch specific Ash-related exceptions
      error in [Ash.Error.Query.NotFound, Ash.Error.Invalid] ->
        Logger.debug("Webhook lookup error: #{inspect(error)}")
        {:error, :webhook_not_found}
    end
  end

  defp validate_create_params(params, map_id) do
    required_fields = ["url", "events"]

    if Enum.all?(required_fields, &Map.has_key?(params, &1)) do
      webhook_params = %{
        map_id: map_id,
        url: params["url"],
        events: params["events"],
        active?: Map.get(params, "active", true)
      }

      {:ok, webhook_params}
    else
      {:error, :invalid_params}
    end
  end

  defp validate_update_params(params) do
    # Filter out non-updatable fields and map identifier
    allowed_fields = ["url", "events", "active"]

    update_params =
      params
      |> Map.take(allowed_fields)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case k do
          "active" -> Map.put(acc, :active?, v)
          "url" -> Map.put(acc, :url, v)
          "events" -> Map.put(acc, :events, v)
          _ -> acc
        end
      end)

    {:ok, update_params}
  end

  defp webhook_to_json(webhook) do
    %{
      id: webhook.id,
      map_id: webhook.map_id,
      url: webhook.url,
      events: webhook.events,
      active: webhook.active?,
      last_delivery_at: webhook.last_delivery_at,
      last_error: webhook.last_error,
      consecutive_failures: webhook.consecutive_failures,
      inserted_at: webhook.inserted_at,
      updated_at: webhook.updated_at
    }
  end
end
