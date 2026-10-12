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
  def parent_in_token_map(path) when is_list(path), do: {__MODULE__.ParentInTokenMap, path: path}

  def create_parent_in_token_map(parent_resource, fk),
    do: {__MODULE__.CreateParentInTokenMap, parent_resource: parent_resource, fk: fk}

  def create_map_matches_token, do: {__MODULE__.CreateMapMatchesToken, []}

  @doc false
  # Build a nested keyword-list filter that walks `path` down to a final
  # `map_id` comparison, e.g. `[system: [map_id: map_id]]`. Shared by the
  # InTokenMap and ParentInTokenMap FilterChecks. See InTokenMap's moduledoc for
  # why the filter is a nested keyword list rather than a dynamic `ref/2` call.
  def build_map_filter(path, map_id) do
    path
    |> Enum.reverse()
    |> Enum.reduce(map_id, fn segment, acc -> [{segment, acc}] end)
  end

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
        %{id: map_id} -> WandererApp.Api.Policies.MapScoped.build_map_filter(path, map_id)
        _ -> expr(false)
      end
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
        %{id: map_id} -> WandererApp.Api.Policies.MapScoped.build_map_filter(path, map_id)
        _ -> expr(false)
      end
    end
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
          # Check the raw params BEFORE the attribute, and check both key
          # types, because each source answers a different question:
          #
          #   * `params["map_id"]` -- what a JSON:API client actually sent. This
          #     is the value being authorized, and it must be read from params
          #     because `InjectMapFromActor` overwrites the *attribute* with the
          #     token's map before policies run. Reading only the attribute
          #     would therefore compare the token map against itself and
          #     authorize every foreign map_id.
          #   * `params[:map_id]` -- the same value when the changeset was built
          #     internally with atom keys (Ash does not normalize params).
          #   * the attribute -- the fallback for resources with no
          #     `InjectMapFromActor` change, where map_id is set directly and
          #     never appears in params.
          #
          # `nil` means the client supplied nothing, so the token's map is
          # injected (or `allow_nil? false` rejects it) -- either way there is
          # no foreign id to forbid.
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
