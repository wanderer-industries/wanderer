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

  @impl true
  def event_metrics(_opts) do
    [
      user_event_metrics(),
      character_event_metrics(),
      map_event_metrics(),
      map_subscription_metrics(),
      characters_distribution_event_metrics()
    ]
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

  defp get_empty_tag_values(_) do
    %{}
  end
end
