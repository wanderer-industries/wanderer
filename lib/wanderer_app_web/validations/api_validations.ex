defmodule WandererAppWeb.Validations.ApiValidations do
  @moduledoc """
  Standardized input validation for API controllers using Ecto changesets.

  This module provides reusable validation schemas and changesets for common
  API input patterns, ensuring consistent 422 responses for validation errors.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @doc """
  Validates map identification parameters (either map_id or slug).
  Returns {:ok, map_identifier} or {:error, changeset}
  """
  def validate_map_identifier(params) do
    types = %{map_id: :string, slug: :string}

    {%{}, types}
    |> cast(params, [:map_id, :slug])
    |> validate_map_identifier_presence()
    |> apply_action(:validate)
    |> case do
      {:ok, validated} ->
        cond do
          validated.map_id -> {:ok, validated.map_id}
          validated.slug -> {:ok, validated.slug}
          true -> {:error, :no_identifier}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp validate_map_identifier_presence(changeset) do
    map_id = get_field(changeset, :map_id)
    slug = get_field(changeset, :slug)

    if is_nil(map_id) and is_nil(slug) do
      add_error(changeset, :base, "Either map_id or slug must be provided")
    else
      changeset
    end
  end

  @doc """
  Validates system ID parameter as integer.
  """
  def validate_system_id(params) do
    types = %{system_id: :integer}

    {%{}, types}
    |> cast(params, [:system_id])
    |> validate_required([:system_id])
    |> apply_action(:validate)
  end

  @doc """
  Validates optional system ID parameter.
  """
  def validate_optional_system_id(params) do
    types = %{system_id: :integer}

    {%{}, types}
    |> cast(params, [:system_id])
    |> apply_action(:validate)
  end

  @doc """
  Validates connection filter parameters.
  """
  def validate_connection_filters(params) do
    types = %{
      solar_system_source: :integer,
      solar_system_target: :integer
    }

    {%{}, types}
    |> cast(params, [:solar_system_source, :solar_system_target])
    |> apply_action(:validate)
  end

  @doc """
  Validates connection creation parameters.
  """
  def validate_connection_params(params) do
    types = %{
      solar_system_source: :integer,
      solar_system_target: :integer
    }

    {%{}, types}
    |> cast(params, [:solar_system_source, :solar_system_target])
    |> validate_required([:solar_system_source, :solar_system_target])
    |> validate_connection_endpoints()
    |> apply_action(:validate)
  end

  defp validate_connection_endpoints(changeset) do
    source = get_field(changeset, :solar_system_source)
    target = get_field(changeset, :solar_system_target)

    if source == target do
      add_error(changeset, :solar_system_target, "cannot be the same as source")
    else
      changeset
    end
  end

  @doc """
  Validates hours parameter for activity queries.
  """
  def validate_hours_param(params) do
    # Accept multiple parameter names for backward compatibility
    hours_value = params["hours"] || params["hours_ago"] || params["hour_ago"]

    types = %{hours: :integer}

    {%{}, types}
    |> cast(%{"hours" => hours_value}, [:hours])
    |> validate_number(:hours, greater_than: 0, less_than_or_equal_to: 168)
    |> apply_action(:validate)
  end

  @doc """
  Validates days parameter for activity queries.
  Defaults to 7 days if not provided.
  """
  def validate_days_param(params) do
    types = %{days: :integer}
    defaults = %{days: 7}

    {defaults, types}
    |> cast(params, [:days])
    |> validate_number(:days, greater_than: 0)
    |> apply_action(:validate)
  end

  @doc """
  Validates ACL creation parameters.
  """
  def validate_acl_params(params) do
    types = %{
      name: :string,
      description: :string,
      owner_eve_id: :string
    }

    acl_params = Map.get(params, "acl", %{})

    {%{}, types}
    |> cast(acl_params, [:name, :description, :owner_eve_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> apply_action(:validate)
  end

  @doc """
  Validates ACL member creation parameters.
  Ensures exactly one entity type is specified and validates role restrictions.
  """
  def validate_acl_member_params(params) do
    member_params = Map.get(params, "member", %{})

    types = %{
      eve_character_id: :string,
      eve_corporation_id: :string,
      eve_alliance_id: :string,
      role: :string
    }

    changeset =
      {%{}, types}
      |> cast(member_params, [:eve_character_id, :eve_corporation_id, :eve_alliance_id, :role])
      |> validate_required([:role])
      |> validate_inclusion(:role, ["admin", "manager", "member", "viewer"])
      |> validate_exactly_one_entity()
      |> validate_entity_role_restrictions()

    apply_action(changeset, :validate)
  end

  defp validate_exactly_one_entity(changeset) do
    char_id = get_field(changeset, :eve_character_id)
    corp_id = get_field(changeset, :eve_corporation_id)
    alliance_id = get_field(changeset, :eve_alliance_id)

    entity_count =
      [char_id, corp_id, alliance_id]
      |> Enum.reject(&is_nil/1)
      |> length()

    case entity_count do
      0 ->
        add_error(
          changeset,
          :base,
          "Must specify exactly one of: eve_character_id, eve_corporation_id, or eve_alliance_id"
        )

      1 ->
        changeset

      _ ->
        add_error(changeset, :base, "Can only specify one entity type at a time")
    end
  end

  defp validate_entity_role_restrictions(changeset) do
    role = get_field(changeset, :role)
    corp_id = get_field(changeset, :eve_corporation_id)
    alliance_id = get_field(changeset, :eve_alliance_id)

    cond do
      corp_id && role in ["admin", "manager"] ->
        add_error(changeset, :role, "Corporation members cannot have admin or manager role")

      alliance_id && role in ["admin", "manager"] ->
        add_error(changeset, :role, "Alliance members cannot have admin or manager role")

      true ->
        changeset
    end
  end

  @doc """
  Validates map system filter parameters.
  """
  def validate_system_filters(params) do
    types = %{
      search: :string,
      status: :integer,
      tag: :string
    }

    {%{}, types}
    |> cast(params, [:search, :status, :tag])
    |> validate_inclusion(:status, [0, 1, 2], message: "must be 0, 1, or 2")
    |> apply_action(:validate)
  end

  @doc """
  Validates pagination parameters.
  """
  def validate_pagination(params) do
    types = %{
      page: :integer,
      page_size: :integer
    }

    defaults = %{
      page: 1,
      page_size: 20
    }

    {defaults, types}
    |> cast(params, [:page, :page_size])
    |> validate_number(:page, greater_than: 0)
    |> validate_number(:page_size, greater_than: 0, less_than_or_equal_to: 100)
    |> apply_action(:validate)
  end

  @doc """
  Validates integer parameter with optional constraints.
  """
  def validate_integer_param(params, key, opts \\ []) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)
    required = Keyword.get(opts, :required, false)

    types = %{key => :integer}

    changeset =
      {%{}, types}
      |> cast(params, [key])

    changeset = if required, do: validate_required(changeset, [key]), else: changeset

    changeset =
      if min, do: validate_number(changeset, key, greater_than_or_equal_to: min), else: changeset

    changeset =
      if max, do: validate_number(changeset, key, less_than_or_equal_to: max), else: changeset

    apply_action(changeset, :validate)
  end

  @doc """
  Validates UUID parameter.
  """
  def validate_uuid_param(params, key, opts \\ []) do
    required = Keyword.get(opts, :required, false)

    types = %{key => Ecto.UUID}

    changeset =
      {%{}, types}
      |> cast(params, [key])

    changeset = if required, do: validate_required(changeset, [key]), else: changeset

    apply_action(changeset, :validate)
  end

  @doc """
  Validates role parameter with entity-type-specific rules.
  """
  def validate_role_for_entity_type(role, entity_type) do
    types = %{role: :string, entity_type: :string}

    changeset =
      {%{}, types}
      |> cast(%{role: role, entity_type: entity_type}, [:role, :entity_type])
      |> validate_required([:role, :entity_type])
      |> validate_inclusion(:role, ["admin", "manager", "member", "viewer"])
      |> validate_role_restrictions()

    apply_action(changeset, :validate)
  end

  defp validate_role_restrictions(changeset) do
    role = get_field(changeset, :role)
    entity_type = get_field(changeset, :entity_type)

    if entity_type in ["corporation", "alliance"] and role in ["admin", "manager"] do
      add_error(
        changeset,
        :role,
        "#{String.capitalize(entity_type)} members cannot have #{role} role"
      )
    else
      changeset
    end
  end

  @doc """
  Validates member filter parameters.
  """
  def validate_member_filters(params) do
    types = %{
      type: :string,
      role: :string
    }

    {%{}, types}
    |> cast(params, [:type, :role])
    |> validate_inclusion(:type, ["character", "corporation", "alliance"])
    |> validate_inclusion(:role, ["admin", "manager", "member", "viewer"])
    |> apply_action(:validate)
  end

  @doc """
  Validates member update parameters.
  """
  def validate_member_update_params(params) do
    types = %{
      role: :string
    }

    {%{}, types}
    |> cast(params, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["admin", "manager", "member", "viewer"])
    |> apply_action(:validate)
  end

  @doc """
  Parses and validates an integer from a string with better error messages.
  """
  def parse_and_validate_integer(value, field_name \\ "value") do
    case value do
      nil ->
        {:ok, nil}

      val when is_integer(val) ->
        {:ok, val}

      val when is_binary(val) ->
        case Integer.parse(val) do
          {num, ""} ->
            {:ok, num}

          _ ->
            changeset =
              {%{}, %{field_name => :integer}}
              |> cast(%{}, [])
              |> add_error(field_name, "must be a valid integer")

            {:error, changeset}
        end

      _ ->
        changeset =
          {%{}, %{field_name => :integer}}
          |> cast(%{}, [])
          |> add_error(field_name, "must be a valid integer")

        {:error, changeset}
    end
  end

  @doc """
  Validates optional integer parameters from params.
  """
  def validate_optional_integer(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      val -> parse_and_validate_integer(val, key)
    end
  end

  @doc """
  Validates required integer parameters from params.
  """
  def validate_required_integer(params, key) do
    case Map.get(params, key) do
      nil ->
        changeset =
          {%{}, %{key => :integer}}
          |> cast(%{}, [])
          |> add_error(key, "is required")

        {:error, changeset}

      val ->
        parse_and_validate_integer(val, key)
    end
  end

  @doc """
  Formats changeset errors into a standardized error response.
  Returns a map suitable for JSON encoding with 422 status.
  """
  def format_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    %{
      error: "Validation failed",
      errors: errors
    }
  end
end
