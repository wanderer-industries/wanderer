defmodule WandererAppWeb.KillmailFactoryTest do
  use ExUnit.Case, async: true

  alias WandererAppWeb.Factory

  test "build(:killmail) produces string keys with required fields" do
    kill = Factory.build(:killmail)

    assert is_integer(kill["killmail_id"])
    assert is_binary(kill["kill_time"])
    assert is_integer(kill["solar_system_id"])
    assert kill["total_value"] == 84_000_000
  end

  test "build(:killmail) accepts atom-key overrides" do
    kill = Factory.build(:killmail, %{victim_ship_name: nil, total_value: 0})

    assert kill["victim_ship_name"] == nil
    assert kill["total_value"] == 0
  end

  test "build(:kill_event) wraps killmails in the batch shape" do
    event = Factory.build(:kill_event)

    assert event["type"] == :killmail_update
    assert [%{"killmail_id" => _}] = event["killmails"]
  end

  test "build(:kill_count_event) has no killmails" do
    event = Factory.build(:kill_count_event)

    assert event["type"] == :kill_count
    refute Map.has_key?(event, "killmails")
  end
end
