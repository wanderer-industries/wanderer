defmodule WandererAppWeb.Helpers.SafeParsing do
  @moduledoc """
  Safe parsing utilities to prevent runtime crashes from invalid input.

  Provides safe alternatives to dangerous parsing functions like
  String.to_integer/1, String.to_atom/1, etc.
  """

  @doc """
  Safely parse a string to integer.

  Returns {:ok, integer} or {:error, :invalid_integer}
  """
  def parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_integer}
    end
  end

  def parse_integer(value) when is_integer(value), do: {:ok, value}
  def parse_integer(_), do: {:error, :invalid_integer}

  @doc """
  Safely parse a string to integer with a default value.

  Returns the parsed integer or the default value.
  """
  def parse_integer(value, default) when is_integer(default) do
    case parse_integer(value) do
      {:ok, int} -> int
      {:error, _} -> default
    end
  end

  @doc """
  Safely parse a string to float.

  Returns {:ok, float} or {:error, :invalid_float}
  """
  def parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_float}
    end
  end

  def parse_float(value) when is_float(value), do: {:ok, value}
  def parse_float(value) when is_integer(value), do: {:ok, value * 1.0}
  def parse_float(_), do: {:error, :invalid_float}

  @doc """
  Safely parse a string to boolean.

  Accepts: "true", "false", "1", "0", "yes", "no", "on", "off"
  Returns {:ok, boolean} or {:error, :invalid_boolean}
  """
  def parse_boolean(value) when is_binary(value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes", "on"] -> {:ok, true}
      v when v in ["false", "0", "no", "off"] -> {:ok, false}
      _ -> {:error, :invalid_boolean}
    end
  end

  def parse_boolean(true), do: {:ok, true}
  def parse_boolean(false), do: {:ok, false}
  def parse_boolean(1), do: {:ok, true}
  def parse_boolean(0), do: {:ok, false}
  def parse_boolean(_), do: {:error, :invalid_boolean}

  @doc """
  Safely convert a string to an atom from a predefined list.

  This prevents atom exhaustion attacks by only allowing known atoms.
  Returns {:ok, atom} or {:error, :invalid_atom}
  """
  def parse_atom(value, allowed_atoms) when is_binary(value) and is_list(allowed_atoms) do
    # Create a map of string -> atom for efficient lookup
    atom_map = Map.new(allowed_atoms, fn atom -> {Atom.to_string(atom), atom} end)

    case Map.get(atom_map, value) do
      nil -> {:error, :invalid_atom}
      atom -> {:ok, atom}
    end
  end

  def parse_atom(value, allowed_atoms) when is_atom(value) and is_list(allowed_atoms) do
    if value in allowed_atoms do
      {:ok, value}
    else
      {:error, :invalid_atom}
    end
  end

  def parse_atom(_, _), do: {:error, :invalid_atom}

  @doc """
  Safely parse a list of values with a given parser function.

  Returns {:ok, [parsed_values]} if all values parse successfully,
  or {:error, {:invalid_at_index, index}} for the first failure.
  """
  def parse_list(values, parser_fn) when is_list(values) and is_function(parser_fn, 1) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case parser_fn.(value) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, _reason} -> {:halt, {:error, {:invalid_at_index, index}}}
      end
    end)
  end

  def parse_list(_, _), do: {:error, :invalid_list}

  @doc """
  Parse with a fallback chain of parsers.

  Tries each parser in order until one succeeds.
  Returns the first successful result or {:error, :all_parsers_failed}
  """
  def parse_with_fallback(value, parsers) when is_list(parsers) do
    Enum.reduce_while(parsers, {:error, :all_parsers_failed}, fn parser, _acc ->
      case parser.(value) do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, _} -> {:cont, {:error, :all_parsers_failed}}
      end
    end)
  end

  @doc """
  Safely parse and validate an integer within a range.

  Returns {:ok, integer} if valid and within range,
  or {:error, reason} where reason is :invalid_integer, :too_small, or :too_large
  """
  def parse_integer_in_range(value, min, max) when is_integer(min) and is_integer(max) do
    with {:ok, int} <- parse_integer(value) do
      cond do
        int < min -> {:error, :too_small}
        int > max -> {:error, :too_large}
        true -> {:ok, int}
      end
    end
  end

  @doc """
  Parse a string timestamp to DateTime.

  Supports ISO8601 format and Unix timestamps.
  Returns {:ok, DateTime.t()} or {:error, :invalid_timestamp}
  """
  def parse_timestamp(value) when is_binary(value) do
    # Try ISO8601 first
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      _ ->
        # Try Unix timestamp
        with {:ok, unix} <- parse_integer(value),
             {:ok, datetime} <- DateTime.from_unix(unix) do
          {:ok, datetime}
        else
          _ -> {:error, :invalid_timestamp}
        end
    end
  end

  def parse_timestamp(%DateTime{} = datetime), do: {:ok, datetime}

  def parse_timestamp(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> {:ok, datetime}
      _ -> {:error, :invalid_timestamp}
    end
  end

  def parse_timestamp(_), do: {:error, :invalid_timestamp}
end
