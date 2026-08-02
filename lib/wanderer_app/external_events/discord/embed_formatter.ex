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

  # ISK magnitude table, largest first: {threshold, divisor, unit, next_unit}.
  # `next_unit` is what a value promotes to when rounding pushes it to >= 1000
  # within its own unit. It is nil at the top so T clamps instead of promoting,
  # which makes self-promotion impossible by construction.
  @isk_units [
    {1_000_000_000_000, 1_000_000_000_000, "T", nil},
    {1_000_000_000, 1_000_000_000, "B", "T"},
    {1_000_000, 1_000_000, "M", "B"},
    {1_000, 1_000, "K", "M"}
  ]

  @doc """
  The per-event kill cap. Exposed so callers can tell which kills were actually
  formatted — the dispatcher must not mark kills past this cap as attempted,
  since they are never rendered into a message.
  """
  @spec max_kills_per_event() :: pos_integer()
  def max_kills_per_event, do: @max_kills_per_event

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
    Enum.find_value(@isk_units, "#{round(value)} ISK", &format_at_unit(value, &1))
  end

  def format_isk(_), do: nil

  defp format_at_unit(value, {threshold, _divisor, _unit, _next}) when value < threshold, do: nil

  defp format_at_unit(value, {_threshold, divisor, unit, next_unit}) do
    case {round_to(value / divisor), next_unit} do
      # Top of the table: clamp rather than promote.
      {rounded, nil} ->
        "#{format_float(rounded)}#{unit} ISK"

      {rounded, next} when rounded >= 1000.0 ->
        "#{format_float(round_to(rounded / 1000))}#{next} ISK"

      {rounded, _} ->
        "#{format_float(rounded)}#{unit} ISK"
    end
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
