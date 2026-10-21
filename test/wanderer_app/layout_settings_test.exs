defmodule WandererApp.LayoutSettingsTest do
  use ExUnit.Case, async: true

  alias WandererApp.LayoutSettings

  describe "normalize/1" do
    test "converts form values and preserves valid layout options" do
      settings =
        LayoutSettings.normalize(%{
          "enabled" => "true",
          "engine" => "dagre",
          "direction" => "LR",
          "routing" => "spline",
          "nodeSpacing" => "55",
          "layerSpacing" => 90,
          "preservePreviousPositions" => "false"
        })

      assert settings["enabled"]
      assert settings["engine"] == "dagre"
      assert settings["direction"] == "LR"
      assert settings["nodeSpacing"] == 55
      assert settings["layerSpacing"] == 90
      refute settings["preservePreviousPositions"]
      assert settings["routing"] == "orthogonal"
    end

    test "replaces invalid values and clamps spacing" do
      settings =
        LayoutSettings.normalize(%{
          "engine" => "unknown",
          "direction" => "sideways",
          "nodeSpacing" => "-5",
          "layerSpacing" => "5000"
        })

      assert settings["engine"] == "elk"
      assert settings["direction"] == "TB"
      assert settings["nodeSpacing"] == 0
      assert settings["layerSpacing"] == 1000
    end
  end

  test "preserve/2 keeps layout settings while replacing other defaults" do
    existing = Jason.encode!(%{"layout" => %{"engine" => "dagre"}, "theme" => "old"})
    updated = LayoutSettings.preserve(Jason.encode!(%{"theme" => "new"}), existing)

    assert Jason.decode!(updated) == %{
             "layout" => %{"engine" => "dagre"},
             "theme" => "new"
           }
  end
end
