defmodule WandererApp.Api.Policies.MapScoped do
  @moduledoc """
  Policy checks scoping `/api/v1` requests to an `ActorWithMap` token's map.

  Trusted internal actors (plain `User`/`Character`) are authorized via a
  bypass and never reach the scoped checks below. A session
  `ActorWithMap{map: nil}` is NOT trusted and must fall through to the scoped
  (and therefore denying) checks.
  """

  def trusted, do: {__MODULE__.Trusted, []}
  def in_token_map(path) when is_list(path), do: {__MODULE__.InTokenMap, path: path}
  def write_direct(attr \\ :map_id), do: {__MODULE__.WriteDirect, attr: attr}
  def parent_in_token_map(path) when is_list(path), do: {__MODULE__.ParentInTokenMap, path: path}

  def create_parent_in_token_map(parent_resource, fk),
    do: {__MODULE__.CreateParentInTokenMap, parent_resource: parent_resource, fk: fk}

  def create_map_matches_token, do: {__MODULE__.CreateMapMatchesToken, []}

  defmodule Trusted do
    @moduledoc """
    Bypass check: matches only plain internal `User`/`Character` actors.
    A session `ActorWithMap{map: nil}` must NEVER match this check.

    Uses `is_struct/2` rather than `%WandererApp.Api.User{}` pattern matching
    on purpose. A struct pattern is expanded at COMPILE time, which makes this
    module depend on `WandererApp.Api.User`. Since `User` itself carries a
    policy referencing this module, that closes a compile-time cycle and
    `mix compile --force` fails with "deadlocked waiting on struct
    WandererApp.Api.User". `is_struct/2` checks the module name at RUNTIME and
    is otherwise exactly equivalent here.
    """
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_), do: "actor is a trusted internal User or Character"

    @impl true
    def match?(actor, _ctx, _opts)
        when is_struct(actor, WandererApp.Api.User)
        when is_struct(actor, WandererApp.Api.Character),
        do: true

    def match?(_actor, _ctx, _opts), do: false
  end

  defmodule InTokenMap do
    @moduledoc """
    Filters rows down to those belonging to the token's map.

    `Ash.Expr.ref/2` takes `(relationship_path, name)`. A dynamically built
    relationship-path ref (e.g. `Ash.Expr.ref([:system], :map_id)`) does not
    resolve through filter hydration the same way a literal
    `expr(system.map_id == ...)` does — it raises
    `Ash.Error.Unknown: "Invalid reference ..."`. We therefore build the
    filter as a nested keyword
    list, which `FilterCheck.filter/3` accepts directly
    (`@callback filter(...) :: Keyword.t() | Ash.Expr.t()`) and which Ash
    resolves through relationships without needing a dynamic `ref/2` call.
    """
    use Ash.Policy.FilterCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "row belongs to the token's map"

    @impl true
    def filter(actor, _ctx, opts) do
      path = Keyword.fetch!(opts, :path)

      case ActorHelpers.get_map(%{actor: actor}) do
        %{id: map_id} -> build_filter(path, map_id)
        _ -> expr(false)
      end
    end

    defp build_filter(path, map_id) do
      path
      |> Enum.reverse()
      |> Enum.reduce(map_id, fn segment, acc -> [{segment, acc}] end)
    end
  end

  defmodule ParentInTokenMap do
    @moduledoc """
    Filters rows down to those whose parent (via relationship path) belongs
    to the token's map. See `InTokenMap` moduledoc for why the filter is
    built as a nested keyword list rather than via a dynamic `ref/2` call.
    """
    use Ash.Policy.FilterCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "row's parent belongs to the token's map"

    @impl true
    def filter(actor, _ctx, opts) do
      path = Keyword.fetch!(opts, :path)

      case ActorHelpers.get_map(%{actor: actor}) do
        %{id: map_id} -> build_filter(path, map_id)
        _ -> expr(false)
      end
    end

    defp build_filter(path, map_id) do
      path
      |> Enum.reverse()
      |> Enum.reduce(map_id, fn segment, acc -> [{segment, acc}] end)
    end
  end

  defmodule WriteDirect do
    @moduledoc """
    Authorizes a write when the changeset's map_id attribute matches the token's map.

    Reads `changeset.data` (via `Ash.Changeset.get_attribute/2`'s fallback to
    `get_data/2`) to cover update/destroy actions where the scoped attribute
    isn't part of the change itself (e.g. `map.ex`'s `write_direct(:id)`, or
    an update that doesn't touch `map_id`). Ash's atomic-query update/destroy
    path skips fetching original data as an optimization unless a check
    declares `requires_original_data?/2` — without this override,
    `changeset.data` becomes `%Ash.Changeset.OriginalDataNotAvailable{}` and
    every atomically-eligible update is wrongly denied.
    """
    use Ash.Policy.SimpleCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "changeset target belongs to the token's map"

    @impl true
    def requires_original_data?(_authorizer, _opts), do: true

    @impl true
    def match?(actor, %{changeset: %Ash.Changeset{} = cs}, opts) do
      attr = Keyword.get(opts, :attr, :map_id)

      with %{id: map_id} <- ActorHelpers.get_map(%{actor: actor}),
           row_map_id when not is_nil(row_map_id) <-
             Ash.Changeset.get_attribute(cs, attr) do
        row_map_id == map_id
      else
        _ -> false
      end
    end

    def match?(_actor, _ctx, _opts), do: false
  end

  defmodule CreateParentInTokenMap do
    @moduledoc """
    Authorizes a create when the row's parent (looked up by foreign key)
    belongs to the token's map.
    """
    use Ash.Policy.SimpleCheck
    require Ash.Query
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "created row's parent belongs to the token's map"

    @impl true
    def match?(actor, %{changeset: %Ash.Changeset{} = cs}, opts) do
      parent = Keyword.fetch!(opts, :parent_resource)
      fk = Keyword.fetch!(opts, :fk)

      with %{id: map_id} <- ActorHelpers.get_map(%{actor: actor}),
           parent_id when not is_nil(parent_id) <- Ash.Changeset.get_attribute(cs, fk) do
        case Ash.read_one(
               Ash.Query.filter(parent, id == ^parent_id and map_id == ^map_id),
               actor: actor,
               authorize?: false
             ) do
          {:ok, nil} -> false
          {:ok, _} -> true
          _ -> false
        end
      else
        _ -> false
      end
    end

    def match?(_actor, _ctx, _opts), do: false
  end

  defmodule CreateMapMatchesToken do
    @moduledoc """
    Authorizes a create when the supplied `map_id` param/attribute is absent
    (it will be injected from the token) or equals the token map. Forbids a
    supplied foreign `map_id`.
    """
    use Ash.Policy.SimpleCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "created row's supplied map_id matches the token map (or is absent)"

    @impl true
    def match?(actor, %{changeset: %Ash.Changeset{} = cs}, _opts) do
      case ActorHelpers.get_map(%{actor: actor}) do
        %{id: map_id} ->
          supplied =
            Map.get(cs.params || %{}, "map_id") || Map.get(cs.params || %{}, :map_id) ||
              Ash.Changeset.get_attribute(cs, :map_id)

          is_nil(supplied) or to_string(supplied) == to_string(map_id)

        _ ->
          false
      end
    end

    def match?(_actor, _ctx, _opts), do: false
  end
end
