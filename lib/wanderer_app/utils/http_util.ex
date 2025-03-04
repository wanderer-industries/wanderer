defmodule WandererApp.Utils.HttpUtil do
  @moduledoc """
  Utility functions for HTTP operations and error handling.
  """

  @doc """
  Determines if an HTTP error is retriable.

  Returns `true` for common transient errors like timeouts and server errors (500, 502, 503, 504).
  """
  def retriable_error?(:timeout), do: true
  def retriable_error?("Unexpected status: 500"), do: true
  def retriable_error?("Unexpected status: 502"), do: true
  def retriable_error?("Unexpected status: 503"), do: true
  def retriable_error?("Unexpected status: 504"), do: true
  def retriable_error?("Request failed"), do: true
  def retriable_error?(_), do: false
end
