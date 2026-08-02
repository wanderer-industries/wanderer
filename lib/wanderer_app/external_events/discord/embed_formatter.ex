defmodule WandererApp.ExternalEvents.Discord.EmbedFormatter do
  @moduledoc """
  Turns flattened killmails into Discord message bodies.

  Only `killmail_id`, `kill_time` and `solar_system_id` are guaranteed present
  on a killmail (see `WandererApp.Kills.MessageHandler`), so every other field
  is rendered defensively.
  """

  @max_embeds_per_message 10
  @max_kills_per_event 30
  @color 0xD9534F

  @zkill_base "https://zkillboard.com/kill/"
  @image_base "https://images.evetech.net"

  @spec format_batch([map()], String.t() | nil) :: [map()]
  def format_batch([], _system_name), do: []

  def format_batch(killmails, system_name) do
    total = length(killmails)
    shown = Enum.take(killmails, @max_kills_per_event)
    overflow = total - length(shown)

    messages =
      shown
      |> Enum.map(&format_kill(&1, system_name))
      |> Enum.chunk_every(@max_embeds_per_message)
      |> Enum.map(&%{"embeds" => &1})

    append_overflow(messages, overflow)
  end

  defp append_overflow(messages, overflow) when overflow <= 0, do: messages

  defp append_overflow(messages, overflow) do
    {init, [last]} = Enum.split(messages, -1)
    init ++ [Map.put(last, "content", "…and #{overflow} more kills not shown.")]
  end

  @spec format_kill(map(), String.t() | nil) :: map()
  def format_kill(kill, system_name) do
    victim = present(kill["victim_char_name"]) || "Unknown pilot"
    ship = present(kill["victim_ship_name"]) || "Unknown ship"

    %{
      "title" => "#{victim} lost a #{ship}",
      "url" => zkill_url(kill["killmail_id"]),
      "color" => @color,
      "timestamp" => present(kill["kill_time"]),
      "fields" => fields(kill, system_name)
    }
    |> maybe_put("thumbnail", thumbnail(kill["victim_ship_type_id"]))
    |> maybe_put("footer", footer(kill))
    |> drop_nils()
  end

  defp fields(kill, system_name) do
    [
      field("System", present(system_name) || "Unknown system", true),
      field("Value", format_isk(kill["total_value"]), true),
      field("Final blow", final_blow(kill), true),
      field("Corp", present(kill["victim_corp_name"]), true),
      field("Alliance", present(kill["victim_alliance_name"]), true)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp field(_name, nil, _inline), do: nil
  defp field(name, value, inline), do: %{"name" => name, "value" => value, "inline" => inline}

  defp final_blow(kill) do
    case {present(kill["final_blow_char_name"]), kill["attacker_count"]} do
      {nil, _} -> nil
      {name, count} when is_integer(count) and count > 1 -> "#{name} (+#{count - 1})"
      {name, _} -> name
    end
  end

  defp footer(kill) do
    case present(kill["victim_corp_ticker"]) do
      nil -> nil
      ticker -> %{"text" => "[#{ticker}]"}
    end
  end

  defp thumbnail(nil), do: nil
  defp thumbnail(type_id), do: %{"url" => "#{@image_base}/types/#{type_id}/render?size=64"}

  defp zkill_url(nil), do: nil
  defp zkill_url(id), do: "#{@zkill_base}#{id}/"

  @doc false
  def format_isk(nil), do: nil
  def format_isk(0), do: "0 ISK"

  def format_isk(value) when is_number(value) do
    # Walk through units from largest to smallest, finding the first one the value fits in.
    # Units table: {threshold, divisor, unit_suffix, next_unit_suffix}
    # The next_unit_suffix is what we promote to if rounding produces >= 1000.0 within this unit.
    # At the top (T), next_unit is nil, signaling CLAMP instead of promote.
    # This makes self-promotion impossible by design (nil != "T").
    units = [
      {1_000_000_000_000, 1_000_000_000_000, "T", nil},  # Trillion: clamp at T (no promotion)
      {1_000_000_000, 1_000_000_000, "B", "T"},          # Billion: promote to T if needed
      {1_000_000, 1_000_000, "M", "B"},                  # Million: promote to B if needed
      {1_000, 1_000, "K", "M"}                           # Thousand: promote to M if needed
    ]

    format_isk_with_units(value, units)
  end

  def format_isk(_), do: nil

  defp format_isk_with_units(value, units) do
    Enum.find_value(units, "#{round(value)} ISK", fn {threshold, divisor, unit, next_unit} ->
      if value >= threshold do
        rounded = round_to(value / divisor)

        cond do
          # If next_unit is nil, clamp: render as-is without dividing or promoting
          is_nil(next_unit) ->
            formatted = format_float(rounded)
            "#{formatted}#{unit} ISK"

          # Otherwise, promote if rounded >= 1000.0
          rounded >= 1000.0 ->
            new_value = round_to(rounded / 1000)
            formatted = format_float(new_value)
            "#{formatted}#{next_unit} ISK"

          # Normal case: render at current unit
          true ->
            formatted = format_float(rounded)
            "#{formatted}#{unit} ISK"
        end
      end
    end)
  end

  # Format a float to avoid scientific notation (e.g., 1.0e3 -> "1000.0")
  defp format_float(float) when is_float(float) do
    # Use format/2 to avoid scientific notation, keeping 1 decimal place
    :erlang.float_to_list(float, [{:decimals, 1}])
    |> List.to_string()
  end

  defp round_to(float), do: Float.round(float, 1)

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: value
  defp present(value), do: to_string(value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp drop_nils(map), do: Map.reject(map, fn {_k, v} -> is_nil(v) end)
end
