defmodule WandererApp.Helpers.LabelCleaner do
  @moduledoc """
  Shared helper module for cleaning map system labels based on map options.

  This module is used by both MapSystemRepo and MapSystem resource to avoid
  circular dependencies.
  """

  @doc """
  Cleans labels based on map options.

  If `store_custom_labels?` is false in map options, filters out all labels
  except the custom label field.

  ## Parameters

  - `labels` - The labels string (JSON format) or any other value
  - `map_opts` - Map options (map or keyword list) containing `:store_custom_labels`

  ## Examples

      iex> clean_labels(~s({"customLabel":"Custom","labels":["A","B"]}), %{store_custom_labels: false})
      ~s({"customLabel":"Custom","labels":[]})

      iex> clean_labels(~s({"customLabel":"Custom","labels":["A","B"]}), %{store_custom_labels: true})
      ~s({"customLabel":"Custom","labels":["A","B"]})

      iex> clean_labels(nil, %{})
      nil
  """
  def clean_labels(labels, map_opts) when is_binary(labels) do
    store_custom_labels? =
      cond do
        is_map(map_opts) -> Map.get(map_opts, :store_custom_labels, false)
        is_list(map_opts) -> Keyword.get(map_opts, :store_custom_labels, false)
        true -> false
      end

    get_filtered_labels(labels, store_custom_labels?)
  end

  def clean_labels(labels, _map_opts), do: labels

  @doc """
  Filters labels based on the store_custom_labels setting.

  When `store_custom_labels?` is true, returns the labels unchanged.
  When false, filters out all labels except the customLabel field.

  ## Parameters

  - `labels` - The labels string (JSON format)
  - `store_custom_labels?` - Boolean indicating whether to keep all labels

  ## Returns

  - The filtered labels as a JSON string, or nil if no custom label exists
  """
  def get_filtered_labels(labels, true) when is_binary(labels) do
    labels
    |> Jason.decode!()
    |> case do
      %{"customLabel" => customLabel} when is_binary(customLabel) ->
        %{"customLabel" => customLabel, "labels" => []}
        |> Jason.encode!()

      _ ->
        nil
    end
  end

  def get_filtered_labels(_, _store_custom_labels), do: nil
end
