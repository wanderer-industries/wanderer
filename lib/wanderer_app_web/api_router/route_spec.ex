defmodule WandererAppWeb.ApiRouter.RouteSpec do
  @moduledoc """
  Structured specification for API routes.

  This module defines the RouteSpec struct that contains all metadata
  needed for routing, feature detection, and API documentation.
  """

  @type verb :: :get | :post | :put | :patch | :delete
  @type segment :: String.t() | atom()

  @type t :: %__MODULE__{
          verb: verb(),
          path: [segment()],
          controller: module(),
          action: atom(),
          features: [String.t()],
          metadata: map()
        }

  @enforce_keys [:verb, :path, :controller, :action]
  defstruct [
    :verb,
    :path,
    :controller,
    :action,
    features: [],
    metadata: %{}
  ]

  @doc """
  Creates a new RouteSpec with default metadata.
  """
  def new(verb, path, controller, action, opts \\ []) do
    features = Keyword.get(opts, :features, [])
    metadata = Keyword.get(opts, :metadata, %{})

    %__MODULE__{
      verb: verb,
      path: path,
      controller: controller,
      action: action,
      features: features,
      metadata: Map.merge(default_metadata(), metadata)
    }
  end

  @doc """
  Returns default metadata for routes.
  """
  def default_metadata do
    %{
      auth_required: false,
      rate_limit: :standard,
      success_status: 200,
      content_type: "application/vnd.api+json",
      description: ""
    }
  end

  @doc """
  Validates a RouteSpec for completeness and correctness.
  """
  def validate(%__MODULE__{} = route_spec) do
    with :ok <- validate_verb(route_spec.verb),
         :ok <- validate_path(route_spec.path),
         :ok <- validate_controller(route_spec.controller),
         :ok <- validate_action(route_spec.action),
         :ok <- validate_features(route_spec.features),
         :ok <- validate_metadata(route_spec.metadata) do
      {:ok, route_spec}
    end
  end

  defp validate_verb(verb) when verb in [:get, :post, :put, :patch, :delete], do: :ok
  defp validate_verb(verb), do: {:error, {:invalid_verb, verb}}

  defp validate_path(path) when is_list(path) do
    if Enum.all?(path, &(is_binary(&1) or is_atom(&1))) do
      :ok
    else
      {:error, {:invalid_path_segments, path}}
    end
  end

  defp validate_path(path), do: {:error, {:invalid_path, path}}

  defp validate_controller(controller) when is_atom(controller), do: :ok
  defp validate_controller(controller), do: {:error, {:invalid_controller, controller}}

  defp validate_action(action) when is_atom(action), do: :ok
  defp validate_action(action), do: {:error, {:invalid_action, action}}

  defp validate_features(features) when is_list(features) do
    if Enum.all?(features, &is_binary/1) do
      :ok
    else
      {:error, {:invalid_features, features}}
    end
  end

  defp validate_features(features), do: {:error, {:invalid_features, features}}

  defp validate_metadata(metadata) when is_map(metadata), do: :ok
  defp validate_metadata(metadata), do: {:error, {:invalid_metadata, metadata}}
end
