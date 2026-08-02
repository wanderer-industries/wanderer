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
    cond do
      value >= 1_000_000_000 -> "#{round_to(value / 1_000_000_000)}B ISK"
      value >= 1_000_000 -> "#{round_to(value / 1_000_000)}M ISK"
      value >= 1_000 -> "#{round_to(value / 1_000)}K ISK"
      true -> "#{round(value)} ISK"
    end
  end

  def format_isk(_), do: nil

  defp round_to(float), do: Float.round(float, 1)

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: value
  defp present(value), do: to_string(value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp drop_nils(map), do: Map.reject(map, fn {_k, v} -> is_nil(v) end)
end
