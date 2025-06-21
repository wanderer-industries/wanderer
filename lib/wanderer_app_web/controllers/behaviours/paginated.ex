defmodule WandererAppWeb.Controllers.Behaviours.Paginated do
  @moduledoc """
  Behaviour for controllers that need pagination functionality.

  This module provides:
  - Consistent OpenAPI parameter definitions
  - Standardized pagination pipeline  
  - Response formatting helpers
  - Error handling patterns

  ## Usage

      defmodule MyAPIController do
        use WandererAppWeb, :controller
        use WandererAppWeb.Controllers.Behaviours.Paginated
        
        def index(conn, params) do
          paginated_response(conn, params) do
            query = MyResource
            {query, &transform_item/1}
          end
        end
        
        defp transform_item(item), do: %{id: item.id, name: item.name}
      end
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias WandererAppWeb.Helpers.PaginationHelpers
  alias WandererAppWeb.Validations.ApiValidations
  alias WandererAppWeb.Schemas.ApiSchemas

  @callback transform_item(any()) :: map()
  @optional_callbacks [transform_item: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour WandererAppWeb.Controllers.Behaviours.Paginated

      import WandererAppWeb.Controllers.Behaviours.Paginated

      # Can be overridden by implementing controllers
      def transform_item(item), do: item

      defoverridable transform_item: 1
    end
  end

  @doc """
  Returns default pagination parameters for OpenAPI specs.
  """
  def pagination_parameters do
    [
      page: [
        in: :query,
        type: :integer,
        description: "Page number (default: 1)",
        example: 1,
        required: false
      ],
      page_size: [
        in: :query,
        type: :integer,
        description: "Items per page (default: 20, max: 100)",
        example: 20,
        required: false
      ]
    ]
  end

  @doc """
  Returns pagination response schema.
  """
  def pagination_response_schema(item_schema) do
    ApiSchemas.paginated_response(item_schema)
  end

  @doc """
  Executes a paginated response pipeline.

  The block should return either:
  - `{query, transform_fn}` - Query will be paginated, items transformed
  - `{query}` - Query will be paginated, items returned as-is
  - `query` - Query will be paginated, items returned as-is

  ## Examples

      paginated_response(conn, params) do
        query = MyResource |> MyResource.for_user(user_id)
        {query, &MyController.transform_item/1}
      end
      
      paginated_response(conn, params) do
        Character |> Character.active()
      end
  """
  defmacro paginated_response(conn, params, do: block) do
    quote do
      WandererAppWeb.Controllers.Behaviours.Paginated.execute_paginated_response(
        unquote(conn),
        unquote(params),
        fn -> unquote(block) end,
        __MODULE__
      )
    end
  end

  @doc false
  def execute_paginated_response(conn, params, block_fn, calling_module) do
    case ApiValidations.validate_pagination(params) do
      {:ok, pagination_params} ->
        merged_params = merge_pagination_params(params, pagination_params)
        {query, transform_fn} = extract_query_and_transform(block_fn.(), calling_module)
        
        handle_paginated_query(conn, query, transform_fn, merged_params)

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> json(ApiValidations.format_errors(changeset))
    end
  end

  # Helper to merge pagination params with string keys
  defp merge_pagination_params(params, pagination_params) do
    pagination_params_string = 
      for {key, value} <- pagination_params, into: %{} do
        {to_string(key), value}
      end
    Map.merge(params, pagination_params_string)
  end

  # Extract query and transform function from block result
  defp extract_query_and_transform(result, calling_module) do
    case result do
      {query, transform_fn} when is_function(transform_fn, 1) ->
        {query, transform_fn}

      {query} ->
        {query, &calling_module.transform_item/1}

      query ->
        {query, &calling_module.transform_item/1}
    end
  end

  # Handle the paginated query execution
  defp handle_paginated_query(conn, query, transform_fn, params) do
    case PaginationHelpers.paginate_query(query, params, WandererApp.Api) do
      {:ok, {data, pagination_meta}} ->
        send_paginated_response(conn, data, transform_fn, pagination_meta)

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(ApiValidations.format_errors(changeset))
    end
  end

  # Transform data and send paginated response
  defp send_paginated_response(conn, data, transform_fn, pagination_meta) do
    transformed_data = Enum.map(data, transform_fn)
    response = PaginationHelpers.format_paginated_response(transformed_data, pagination_meta)

    conn
    |> PaginationHelpers.add_pagination_headers(pagination_meta, conn.request_path)
    |> put_status(200)
    |> json(response)
  end

  @doc """
  Executes a paginated response for lists (not Ash queries).

  The block should return a list that will be paginated in memory.
  Use sparingly - prefer database-level pagination when possible.
  """
  defmacro paginated_list_response(conn, params, do: block) do
    quote do
      WandererAppWeb.Controllers.Behaviours.Paginated.execute_paginated_list_response(
        unquote(conn),
        unquote(params),
        fn -> unquote(block) end,
        __MODULE__
      )
    end
  end

  @doc false
  def execute_paginated_list_response(conn, params, block_fn, calling_module) do
    case ApiValidations.validate_pagination(params) do
      {:ok, pagination_params} ->
        merged_params = merge_pagination_params(params, pagination_params)
        data_list = block_fn.()
        
        handle_paginated_list(conn, data_list, merged_params, calling_module)

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> json(ApiValidations.format_errors(changeset))
    end
  end

  # Handle paginated list execution
  defp handle_paginated_list(conn, data_list, params, calling_module) do
    case PaginationHelpers.paginate_list(data_list, params) do
      {:ok, {data, pagination_meta}} ->
        transform_fn = &calling_module.transform_item/1
        send_paginated_response(conn, data, transform_fn, pagination_meta)

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end

  @doc """
  Helper to create OpenAPI operation with pagination parameters.

  ## Example

      @operation_with_pagination %{
        summary: "List characters",
        responses: %{
          200 => paginated_operation_response("Successful response", CharacterSchema)
        }
      }
      def index(conn, params), do: # ...
  """
  def paginated_operation_response(description, item_schema) do
    %{
      description: description,
      content: %{
        "application/json" => %{
          schema: ApiSchemas.paginated_response(item_schema)
        }
      },
      headers: %{
        "X-Page" => %{
          description: "Current page number",
          schema: %{type: :integer}
        },
        "X-Total-Pages" => %{
          description: "Total number of pages",
          schema: %{type: :integer}
        },
        "X-Total-Count" => %{
          description: "Total number of items",
          schema: %{type: :integer}
        },
        "Link" => %{
          description: "Pagination links (first, prev, next, last)",
          schema: %{type: :string}
        }
      }
    }
  end
end
