defmodule WandererApp.Metrics.PromExPlugin do
  use PromEx.Plugin

  @character_tracker_event [:wanderer_app, :character, :tracker]
  @character_tracker_started_event [:wanderer_app, :character, :tracker, :started]
  @character_tracker_stopped_event [:wanderer_app, :character, :tracker, :stopped]
  @user_registered_event [:wanderer_app, :user, :registered]
  @user_character_registered_event [:wanderer_app, :user, :character, :registered]
  @map_character_added_event [:wanderer_app, :map, :character, :added]
  @map_character_jump_event [:wanderer_app, :map, :character, :jump]
  @map_created_event [:wanderer_app, :map, :created]
  @map_started_event [:wanderer_app, :map, :started]
  @map_stopped_event [:wanderer_app, :map, :stopped]
  @map_subscription_new_event [:wanderer_app, :map, :subscription, :new]
  @map_subscription_renew_event [:wanderer_app, :map, :subscription, :renew]
  @map_subscription_update_event [:wanderer_app, :map, :subscription, :update]
  @map_subscription_cancel_event [:wanderer_app, :map, :subscription, :cancel]
  @map_subscription_expired_event [:wanderer_app, :map, :subscription, :expired]

  # ESI-related events
  @esi_rate_limited_event [:wanderer_app, :esi, :rate_limited]
  @esi_error_event [:wanderer_app, :esi, :error]

  # JSON:API v1 related events
  @json_api_request_event [:wanderer_app, :json_api, :request]
  @json_api_response_event [:wanderer_app, :json_api, :response]
  @json_api_auth_event [:wanderer_app, :json_api, :auth]
  @json_api_error_event [:wanderer_app, :json_api, :error]

  @impl true
  def event_metrics(_opts) do
    base_metrics = [
      user_event_metrics(),
      map_event_metrics(),
      map_subscription_metrics()
    ]

    advanced_metrics = [
      character_event_metrics(),
      characters_distribution_event_metrics(),
      esi_event_metrics(),
      json_api_metrics()
    ]

    if WandererApp.Env.base_metrics_only() do
      base_metrics
    else
      base_metrics ++ advanced_metrics
    end
  end

  defp user_event_metrics do
    Event.build(
      :wanderer_app_user_event_metrics,
      [
        counter(
          @user_registered_event ++ [:count],
          event_name: @user_registered_event,
          description: "The number of users registered events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @user_character_registered_event ++ [:count],
          event_name: @user_character_registered_event,
          description: "The number of users character registered events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        )
      ]
    )
  end

  defp character_event_metrics do
    Event.build(
      :wanderer_app_character_event_metrics,
      [
        counter(
          @character_tracker_started_event ++ [:count],
          event_name: @character_tracker_started_event,
          description: "The number of character tracker started events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @character_tracker_stopped_event ++ [:count],
          event_name: @character_tracker_stopped_event,
          description: "The number of character tracker stopped events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        )
      ]
    )
  end

  defp map_event_metrics do
    Event.build(
      :wanderer_app_map_event_metrics,
      [
        counter(
          @map_created_event ++ [:count],
          event_name: @map_created_event,
          description: "The number of map created events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_started_event ++ [:count],
          event_name: @map_started_event,
          description: "The number of map started events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_stopped_event ++ [:count],
          event_name: @map_stopped_event,
          description: "The number of map stopped events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_character_added_event ++ [:count],
          event_name: @map_character_added_event,
          description: "The number of map character added events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_character_jump_event ++ [:count],
          event_name: @map_character_jump_event,
          description: "The number of map character jump events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        )
      ]
    )
  end

  defp map_subscription_metrics do
    Event.build(
      :wanderer_app_map_subscription_metrics,
      [
        counter(
          @map_subscription_new_event ++ [:count],
          event_name: @map_subscription_new_event,
          description: "The number of new map subscription events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_subscription_renew_event ++ [:count],
          event_name: @map_subscription_renew_event,
          description: "The number of map subscription renew events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_subscription_update_event ++ [:count],
          event_name: @map_subscription_update_event,
          description: "The number of map subscription update events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_subscription_cancel_event ++ [:count],
          event_name: @map_subscription_cancel_event,
          description:
            "The number of map character subscription cancel events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        ),
        counter(
          @map_subscription_expired_event ++ [:count],
          event_name: @map_subscription_expired_event,
          description:
            "The number of map character subscription expired events that have occurred",
          tags: [],
          tag_values: &get_empty_tag_values/1
        )
      ]
    )
  end

  defp characters_distribution_event_metrics do
    Event.build(
      :wanderer_app_characters_distribution_event_metrics,
      [
        distribution(
          @character_tracker_event ++ [:duration],
          event_name: @character_tracker_event,
          description: "The time spent in hours before disconnecting from the mapper.",
          reporter_options: [buckets: [1, 2, 4, 8, 16, 32]]
        )
      ]
    )
  end

  defp esi_event_metrics do
    Event.build(
      :wanderer_app_esi_event_metrics,
      [
        counter(
          @esi_rate_limited_event ++ [:count],
          event_name: @esi_rate_limited_event,
          description: "The number of ESI rate limiting incidents that have occurred",
          tags: [:endpoint, :method, :tracking_pool],
          tag_values: &get_esi_tag_values/1
        ),
        distribution(
          @esi_rate_limited_event ++ [:reset_duration],
          event_name: @esi_rate_limited_event,
          description: "ESI rate limit reset duration in milliseconds",
          tags: [:endpoint, :method, :tracking_pool],
          tag_values: &get_esi_tag_values/1,
          reporter_options: [buckets: [1000, 5000, 10000, 30000, 60000, 300_000]]
        ),
        counter(
          @esi_error_event ++ [:count],
          event_name: @esi_error_event,
          description: "The number of ESI API errors that have occurred",
          tags: [:endpoint, :error_type, :tracking_pool],
          tag_values: &get_esi_error_tag_values/1
        )
      ]
    )
  end

  defp get_esi_tag_values(metadata) do
    %{
      endpoint: Map.get(metadata, :endpoint, "unknown"),
      method: Map.get(metadata, :method, "unknown"),
      tracking_pool: Map.get(metadata, :tracking_pool, "unknown")
    }
  end

  defp get_esi_error_tag_values(metadata) do
    %{
      endpoint: Map.get(metadata, :endpoint, "unknown"),
      error_type: inspect(Map.get(metadata, :error_type, "unknown")),
      tracking_pool: Map.get(metadata, :tracking_pool, "default")
    }
  end

  defp get_empty_tag_values(_) do
    %{}
  end

  defp json_api_metrics do
    Event.build(
      :wanderer_app_json_api_metrics,
      [
        # Request metrics
        counter(
          @json_api_request_event ++ [:count],
          event_name: @json_api_request_event,
          description: "The number of JSON:API v1 requests that have occurred",
          tags: [:resource, :action, :method],
          tag_values: &get_json_api_request_tag_values/1
        ),
        distribution(
          @json_api_request_event ++ [:duration],
          event_name: @json_api_request_event,
          description: "The time spent processing JSON:API v1 requests in milliseconds",
          tags: [:resource, :action, :method],
          tag_values: &get_json_api_request_tag_values/1,
          reporter_options: [buckets: [50, 100, 200, 500, 1000, 2000, 5000, 10000]]
        ),
        distribution(
          @json_api_request_event ++ [:payload_size],
          event_name: @json_api_request_event,
          description: "The size of JSON:API v1 request payloads in bytes",
          tags: [:resource, :action, :method],
          tag_values: &get_json_api_request_tag_values/1,
          reporter_options: [buckets: [1024, 10240, 51200, 102_400, 512_000, 1_048_576]]
        ),

        # Response metrics
        counter(
          @json_api_response_event ++ [:count],
          event_name: @json_api_response_event,
          description: "The number of JSON:API v1 responses that have occurred",
          tags: [:resource, :action, :method, :status_code],
          tag_values: &get_json_api_response_tag_values/1
        ),
        distribution(
          @json_api_response_event ++ [:payload_size],
          event_name: @json_api_response_event,
          description: "The size of JSON:API v1 response payloads in bytes",
          tags: [:resource, :action, :method, :status_code],
          tag_values: &get_json_api_response_tag_values/1,
          reporter_options: [buckets: [1024, 10240, 51200, 102_400, 512_000, 1_048_576]]
        ),

        # Authentication metrics
        counter(
          @json_api_auth_event ++ [:count],
          event_name: @json_api_auth_event,
          description: "The number of JSON:API v1 authentication events that have occurred",
          tags: [:auth_type, :result],
          tag_values: &get_json_api_auth_tag_values/1
        ),
        distribution(
          @json_api_auth_event ++ [:duration],
          event_name: @json_api_auth_event,
          description: "The time spent on JSON:API v1 authentication in milliseconds",
          tags: [:auth_type, :result],
          tag_values: &get_json_api_auth_tag_values/1,
          reporter_options: [buckets: [10, 25, 50, 100, 250, 500, 1000]]
        ),

        # Error metrics
        counter(
          @json_api_error_event ++ [:count],
          event_name: @json_api_error_event,
          description: "The number of JSON:API v1 errors that have occurred",
          tags: [:resource, :error_type, :status_code],
          tag_values: &get_json_api_error_tag_values/1
        )
      ]
    )
  end

  defp get_json_api_request_tag_values(metadata) do
    %{
      resource: Map.get(metadata, :resource, "unknown"),
      action: Map.get(metadata, :action, "unknown"),
      method: Map.get(metadata, :method, "unknown")
    }
  end

  defp get_json_api_response_tag_values(metadata) do
    %{
      resource: Map.get(metadata, :resource, "unknown"),
      action: Map.get(metadata, :action, "unknown"),
      method: Map.get(metadata, :method, "unknown"),
      status_code: to_string(Map.get(metadata, :status_code, "unknown"))
    }
  end

  defp get_json_api_auth_tag_values(metadata) do
    %{
      auth_type: Map.get(metadata, :auth_type, "unknown"),
      result: Map.get(metadata, :result, "unknown")
    }
  end

  defp get_json_api_error_tag_values(metadata) do
    %{
      resource: Map.get(metadata, :resource, "unknown"),
      error_type: to_string(Map.get(metadata, :error_type, "unknown")),
      status_code: to_string(Map.get(metadata, :status_code, "unknown"))
    }
  end
end
