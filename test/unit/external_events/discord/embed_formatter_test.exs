defmodule WandererApp.ExternalEvents.Discord.EmbedFormatterTest do
  use ExUnit.Case, async: true

  alias WandererApp.ExternalEvents.Discord.EmbedFormatter
  alias WandererAppWeb.Factory

  describe "format_kill/2" do
    test "includes victim, ship, system and zkill url" do
      kill = Factory.build(:killmail, %{killmail_id: 12_345})
      embed = EmbedFormatter.format_kill(kill, "J123456")

      assert embed["url"] == "https://zkillboard.com/kill/12345/"
      assert embed["title"] =~ "Test Victim"
      assert embed["title"] =~ "Vexor"
      assert Enum.any?(embed["fields"], &(&1["value"] =~ "J123456"))
    end

    test "formats isk value human-readably" do
      kill = Factory.build(:killmail, %{total_value: 84_000_000})
      embed = EmbedFormatter.format_kill(kill, "J123456")

      assert Enum.any?(embed["fields"], fn f -> f["value"] =~ "84" end)
    end

    test "renders ship thumbnail from type id" do
      kill = Factory.build(:killmail, %{victim_ship_type_id: 626})
      embed = EmbedFormatter.format_kill(kill, "J123456")

      assert embed["thumbnail"]["url"] ==
               "https://images.evetech.net/types/626/render?size=64"
    end

    test "survives a nil ship name" do
      kill = Factory.build(:killmail, %{victim_ship_name: nil})
      embed = EmbedFormatter.format_kill(kill, "J123456")

      assert is_binary(embed["title"])
      refute embed["title"] =~ "nil"
    end

    test "survives nil victim, corp, alliance and value" do
      kill =
        Factory.build(:killmail, %{
          victim_char_name: nil,
          victim_corp_name: nil,
          victim_alliance_name: nil,
          victim_ship_name: nil,
          victim_ship_type_id: nil,
          total_value: nil
        })

      embed = EmbedFormatter.format_kill(kill, nil)

      assert is_binary(embed["title"])
      refute Jason.encode!(embed) =~ "nil"
    end

    test "omits thumbnail when ship type id is missing" do
      kill = Factory.build(:killmail, %{victim_ship_type_id: nil})
      embed = EmbedFormatter.format_kill(kill, "J123456")

      refute Map.has_key?(embed, "thumbnail")
    end

    test "is JSON-encodable" do
      kill = Factory.build(:killmail)
      assert {:ok, _} = Jason.encode(EmbedFormatter.format_kill(kill, "J123456"))
    end
  end

  describe "format_batch/2" do
    test "single message for 10 or fewer kills" do
      kills = for _ <- 1..10, do: Factory.build(:killmail)
      assert [%{"embeds" => embeds}] = EmbedFormatter.format_batch(kills, "J123456")
      assert length(embeds) == 10
    end

    test "chunks into messages of at most 10 embeds" do
      kills = for _ <- 1..25, do: Factory.build(:killmail)
      messages = EmbedFormatter.format_batch(kills, "J123456")

      assert length(messages) == 3
      assert Enum.all?(messages, &(length(&1["embeds"]) <= 10))
      assert messages |> Enum.map(&length(&1["embeds"])) |> Enum.sum() == 25
    end

    test "caps at 30 kills and notes the overflow" do
      kills = for _ <- 1..42, do: Factory.build(:killmail)
      messages = EmbedFormatter.format_batch(kills, "J123456")

      total = messages |> Enum.map(&length(&1["embeds"])) |> Enum.sum()
      assert total == 30

      last = List.last(messages)
      assert last["content"] =~ "12 more"
    end

    test "returns empty list for no kills" do
      assert EmbedFormatter.format_batch([], "J123456") == []
    end
  end
end
