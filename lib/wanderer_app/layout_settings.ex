defmodule WandererApp.LayoutSettings do
  @moduledoc false

  @defaults %{
    "enabled" => false,
    "engine" => "elk",
    "direction" => "TB",
    "routing" => "orthogonal",
    "verticalNodeSpacing" => 24,
    "verticalLayerSpacing" => 52,
    "verticalEdgeSpacing" => 12,
    "horizontalNodeSpacing" => 40,
    "horizontalLayerSpacing" => 80,
    "horizontalEdgeSpacing" => 16,
    "orderBy" => "added-at",
    "orderDirection" => "asc",
    "locale" => "en",
    "orderPolicy" => "prefer",
    "groups" => "none",
    "preservePreviousPositions" => true
  }

  @select_options %{
    "engine" => ~w(elk dagre),
    "direction" => ~w(TB BT LR RL),
    "orderBy" => ~w(added-at name id previous-order),
    "orderDirection" => ~w(asc desc),
    "orderPolicy" => ~w(strict prefer crossings-first),
    "groups" => ~w(none compound)
  }

  @integer_options %{
    "verticalNodeSpacing" => "nodeSpacing",
    "verticalLayerSpacing" => "layerSpacing",
    "verticalEdgeSpacing" => "edgeSpacing",
    "horizontalNodeSpacing" => "nodeSpacing",
    "horizontalLayerSpacing" => "layerSpacing",
    "horizontalEdgeSpacing" => "edgeSpacing"
  }
  @boolean_options ~w(enabled preservePreviousPositions)

  def defaults, do: @defaults

  def get(map_id) do
    case WandererApp.Api.MapDefaultSettings.get_by_map_id(%{map_id: map_id}) do
      {:ok, [settings | _]} ->
        settings.settings
        |> decode()
        |> Map.get("layout", %{})
        |> normalize()

      _ ->
        @defaults
    end
  end

  def save(map_id, layout_settings, current_user) do
    actor = first_character(current_user)

    if actor do
      persist(map_id, normalize(layout_settings), actor)
    else
      {:error, :no_character}
    end
  end

  def preserve(serialized_settings, existing_settings) do
    layout = existing_settings |> decode() |> Map.get("layout")
    decoded = decode(serialized_settings)
    merged = if is_nil(layout), do: decoded, else: Map.put(decoded, "layout", layout)
    Jason.encode!(merged)
  end

  def normalize(settings) when is_map(settings) do
    normalized =
      Enum.reduce(@select_options, @defaults, fn {key, allowed}, result ->
        value = Map.get(settings, key, Map.fetch!(@defaults, key))
        normalized_value = if value in allowed, do: value, else: Map.fetch!(@defaults, key)
        Map.put(result, key, normalized_value)
      end)

    normalized =
      Enum.reduce(@integer_options, normalized, fn {key, legacy_key}, result ->
        fallback = Map.get(settings, legacy_key, Map.fetch!(@defaults, key))
        value = settings |> Map.get(key, fallback) |> normalize_integer(key)
        Map.put(result, key, value)
      end)

    normalized =
      Enum.reduce(@boolean_options, normalized, fn key, result ->
        value = settings |> Map.get(key, Map.fetch!(@defaults, key)) |> normalize_boolean()
        Map.put(result, key, value)
      end)

    locale =
      case Map.get(settings, "locale", @defaults["locale"]) do
        value when is_binary(value) and byte_size(value) > 0 -> value
        _ -> @defaults["locale"]
      end

    Map.put(normalized, "locale", locale)
  end

  def normalize(_settings), do: @defaults

  def decode(settings) when is_map(settings), do: settings

  def decode(settings) when is_binary(settings) do
    case Jason.decode(settings) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> %{}
    end
  end

  def decode(_settings), do: %{}

  defp persist(map_id, layout_settings, actor) do
    case WandererApp.Api.MapDefaultSettings.get_by_map_id(%{map_id: map_id}) do
      {:ok, [existing | _]} ->
        settings = existing.settings |> decode() |> Map.put("layout", layout_settings)

        WandererApp.Api.MapDefaultSettings.update(
          existing,
          %{settings: Jason.encode!(settings)},
          actor: actor
        )

      _ ->
        WandererApp.Api.MapDefaultSettings.create(
          %{map_id: map_id, settings: Jason.encode!(%{"layout" => layout_settings})},
          actor: actor
        )
    end
  end

  defp first_character(%{characters: [character | _]}), do: character
  defp first_character(_current_user), do: nil

  defp normalize_integer(value, key) when is_integer(value),
    do: clamp_integer(value, key)

  defp normalize_integer(value, key) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> clamp_integer(integer, key)
      _ -> Map.fetch!(@defaults, key)
    end
  end

  defp normalize_integer(_value, key), do: Map.fetch!(@defaults, key)

  defp clamp_integer(value, _key), do: value |> max(0) |> min(1000)

  defp normalize_boolean(value) when value in [true, "true", "on", "1"], do: true
  defp normalize_boolean(_value), do: false
end
