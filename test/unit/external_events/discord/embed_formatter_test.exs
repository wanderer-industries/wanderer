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

    test "handles ISK formatting boundary values correctly" do
      test_cases = [
        {0, "0 ISK"},
        {999, "999 ISK"},
        {1_000, "1.0K ISK"},
        {999_999, "1.0M ISK"},
        {1_000_000, "1.0M ISK"},
        {999_999_999, "1.0B ISK"},
        {1_500_000_000, "1.5B ISK"},
        {nil, nil}
      ]

      Enum.each(test_cases, fn {value, expected} ->
        actual = EmbedFormatter.format_isk(value)

        assert actual == expected,
               "format_isk(#{inspect(value)}) returned #{inspect(actual)}, expected #{inspect(expected)}"
      end)
    end

    test "handles trillion-ISK values correctly (supercapital/structure kills)" do
      test_cases = [
        # Just under 1 trillion, rounds up to 1T
        {999_999_999_999, "1.0T ISK"},
        # Exactly 1 trillion
        {1_000_000_000_000, "1.0T ISK"},
        # 5 trillion (clearly absurd but reachable)
        {5_000_000_000_000, "5.0T ISK"}
      ]

      Enum.each(test_cases, fn {value, expected} ->
        actual = EmbedFormatter.format_isk(value)

        assert actual == expected,
               "format_isk(#{inspect(value)}) returned #{inspect(actual)}, expected #{inspect(expected)}"
      end)
    end

    test "clamps at trillion unit (does not underreport above 1 quadrillion)" do
      # Above the largest unit, clamping prevents silent magnitude loss.
      # 1 quadrillion must render >= "1000.0T ISK", never "1.0T ISK".
      test_cases = [
        # 100 trillion, correct
        {100_000_000_000_000, "100.0T ISK"},
        # 999 trillion, correct
        {999_000_000_000_000, "999.0T ISK"},
        # 1 quadrillion, clamped at T (not "1.0T")
        {1_000_000_000_000_000, "1000.0T ISK"},
        # Just under 1 quadrillion, rounds to 1000T
        {999_999_999_999_999, "1000.0T ISK"}
      ]

      Enum.each(test_cases, fn {value, expected} ->
        actual = EmbedFormatter.format_isk(value)

        assert actual == expected,
               "format_isk(#{inspect(value)}) returned #{inspect(actual)}, expected #{inspect(expected)}"
      end)
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

    test "exactly 30 kills has no overflow notation" do
      kills = for _ <- 1..30, do: Factory.build(:killmail)
      messages = EmbedFormatter.format_batch(kills, "J123456")

      total = messages |> Enum.map(&length(&1["embeds"])) |> Enum.sum()
      assert total == 30

      last = List.last(messages)
      refute Map.has_key?(last, "content")
    end

    test "returns empty list for no kills" do
      assert EmbedFormatter.format_batch([], "J123456") == []
    end
  end
end
