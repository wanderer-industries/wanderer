defmodule WandererAppWeb.ApiRouter.RouteSpecTest do
  use ExUnit.Case, async: true

  alias WandererAppWeb.ApiRouter.RouteSpec

  describe "RouteSpec.new/4" do
    test "creates a valid RouteSpec with minimal parameters" do
      spec = RouteSpec.new(:get, ~w(api v1 maps), MyController, :index)

      assert spec.verb == :get
      assert spec.path == ~w(api v1 maps)
      assert spec.controller == MyController
      assert spec.action == :index
      assert spec.features == []
      assert is_map(spec.metadata)
    end

    test "creates RouteSpec with features and metadata" do
      features = ~w(filtering sorting)
      metadata = %{auth_required: true, description: "Test route"}

      spec =
        RouteSpec.new(:post, ~w(api v1 maps), MyController, :create,
          features: features,
          metadata: metadata
        )

      assert spec.features == features
      assert spec.metadata.auth_required == true
      assert spec.metadata.description == "Test route"
      # Should merge with defaults
      assert spec.metadata.rate_limit == :standard
    end
  end

  describe "RouteSpec.default_metadata/0" do
    test "returns expected default metadata" do
      defaults = RouteSpec.default_metadata()

      assert defaults.auth_required == false
      assert defaults.rate_limit == :standard
      assert defaults.success_status == 200
      assert defaults.content_type == "application/vnd.api+json"
      assert defaults.description == ""
    end
  end

  describe "RouteSpec.validate/1" do
    test "validates a correct RouteSpec" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index,
        features: ~w(filtering),
        metadata: %{auth_required: false}
      }

      assert {:ok, ^spec} = RouteSpec.validate(spec)
    end

    test "validates path with atoms for parameters" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps) ++ [:id],
        controller: MyController,
        action: :show,
        features: [],
        metadata: %{}
      }

      assert {:ok, ^spec} = RouteSpec.validate(spec)
    end

    test "rejects invalid verb" do
      spec = %RouteSpec{
        verb: :invalid_verb,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index,
        features: [],
        metadata: %{}
      }

      assert {:error, {:invalid_verb, :invalid_verb}} = RouteSpec.validate(spec)
    end

    test "rejects invalid path format" do
      spec = %RouteSpec{
        verb: :get,
        path: "not_a_list",
        controller: MyController,
        action: :index,
        features: [],
        metadata: %{}
      }

      assert {:error, {:invalid_path, "not_a_list"}} = RouteSpec.validate(spec)
    end

    test "rejects path with invalid segments" do
      spec = %RouteSpec{
        verb: :get,
        # Number in path
        path: ["api", "v1", 123],
        controller: MyController,
        action: :index,
        features: [],
        metadata: %{}
      }

      assert {:error, {:invalid_path_segments, ["api", "v1", 123]}} = RouteSpec.validate(spec)
    end

    test "rejects invalid controller" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: "not_an_atom",
        action: :index,
        features: [],
        metadata: %{}
      }

      assert {:error, {:invalid_controller, "not_an_atom"}} = RouteSpec.validate(spec)
    end

    test "rejects invalid action" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: "not_an_atom",
        features: [],
        metadata: %{}
      }

      assert {:error, {:invalid_action, "not_an_atom"}} = RouteSpec.validate(spec)
    end

    test "rejects invalid features format" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index,
        features: "not_a_list",
        metadata: %{}
      }

      assert {:error, {:invalid_features, "not_a_list"}} = RouteSpec.validate(spec)
    end

    test "rejects features with non-string elements" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index,
        # Mix of atom and string
        features: [:filtering, "sorting"],
        metadata: %{}
      }

      assert {:error, {:invalid_features, [:filtering, "sorting"]}} = RouteSpec.validate(spec)
    end

    test "rejects invalid metadata format" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index,
        features: [],
        metadata: "not_a_map"
      }

      assert {:error, {:invalid_metadata, "not_a_map"}} = RouteSpec.validate(spec)
    end
  end

  describe "struct enforcement" do
    test "enforces required keys" do
      # This should raise when creating a RouteSpec without required keys
      assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
        struct!(RouteSpec, features: [])
      end
    end

    test "allows creation with all required keys" do
      spec = %RouteSpec{
        verb: :get,
        path: ~w(api v1 maps),
        controller: MyController,
        action: :index
      }

      assert spec.verb == :get
      # Default value
      assert spec.features == []
      # Default value
      assert spec.metadata == %{}
    end
  end
end
