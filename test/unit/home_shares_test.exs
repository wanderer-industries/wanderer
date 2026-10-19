defmodule WandererApp.Map.HomeSharesTest do
  @moduledoc """
  Sharing a home by token: what a map hands out, and what it refuses.
  """

  use WandererApp.DataCase, async: false

  alias WandererApp.Api.Map, as: MapResource
  alias WandererApp.Map.HomeShares

  @home 31_001_269

  setup do
    subscriber = WandererAppWeb.Factory.create_map()
    shared = WandererAppWeb.Factory.create_map()

    %{subscriber: subscriber, shared: shared}
  end

  describe "add/2" do
    test "a map that shares nothing cannot be subscribed to", %{
      subscriber: subscriber,
      shared: shared
    } do
      assert {:error, :not_shared} =
               HomeShares.add(subscriber.id, %{"slug" => shared.slug, "token" => "whatever"})
    end

    test "the wrong token is refused", %{subscriber: subscriber, shared: shared} do
      {:ok, shared} = share(shared)

      assert {:error, :forbidden} =
               HomeShares.add(subscriber.id, %{"slug" => shared.slug, "token" => "not-the-token"})
    end

    test "a slug nobody has is refused", %{subscriber: subscriber} do
      assert {:error, :no_such_map} =
               HomeShares.add(subscriber.id, %{"slug" => "no-such-map", "token" => "x"})
    end

    test "the right token on this instance is kept and listed", %{
      subscriber: subscriber,
      shared: shared
    } do
      {:ok, shared} = share(shared)

      assert {:ok, %{remote?: false}} =
               HomeShares.add(subscriber.id, %{
                 "slug" => shared.slug,
                 "token" => shared.home_share_token,
                 "label" => "Their chain"
               })

      assert [%{label: "Their chain", remote?: false}] = HomeShares.list(subscriber.id)
    end

    test "the same map added twice stays one share", %{subscriber: subscriber, shared: shared} do
      {:ok, shared} = share(shared)

      params = %{"slug" => shared.slug, "token" => shared.home_share_token}

      assert {:ok, _} = HomeShares.add(subscriber.id, params)
      assert {:ok, _} = HomeShares.add(subscriber.id, params)

      assert length(HomeShares.list(subscriber.id)) == 1
    end
  end

  describe "homes/1 and ways_in/1" do
    test "a shared home comes back with the map it belongs to", %{
      subscriber: subscriber,
      shared: shared
    } do
      {:ok, shared} = share(shared)

      {:ok, _} =
        HomeShares.add(subscriber.id, %{
          "slug" => shared.slug,
          "token" => shared.home_share_token
        })

      assert [%{solar_system_id: @home, remote?: false, share_id: share_id}] =
               HomeShares.homes(subscriber.id)

      assert {:ok, %{"home" => home, "ways_in" => ways_in}} = HomeShares.ways_in(share_id)
      assert home["solar_system_id"] == @home
      assert %{"systems" => _, "connections" => _, "markers" => _} = ways_in
    end
  end

  describe "payload_for/1" do
    test "carries the home and nothing about the rest of the chain", %{shared: shared} do
      {:ok, shared} = share(shared)

      payload = HomeShares.payload_for(shared)

      assert payload["home"]["solar_system_id"] == @home
      assert payload["home"]["map_slug"] == shared.slug
      assert Map.keys(payload) |> Enum.sort() == ["home", "ways_in"]
    end
  end

  defp share(map) do
    {:ok, map} = MapResource.update_home_system(map, %{home_solar_system_id: @home})

    MapResource.update_home_share_token(map, %{home_share_token: "a-token"})
  end
end
