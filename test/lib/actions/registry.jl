const ACTION_SCOPE_BENCH = :bench
const ACTION_SCOPE_LIVE = :live

"""
    ActionSpec

Registry entry for one action identifier with scope-specific handlers.
"""
struct ActionSpec
    id::String
    scopes::Set{Symbol}
    apply_bench!::Union{Nothing,Function}
    apply_live!::Union{Nothing,Function}
    live_triggers_render::Bool
end

function _action_spec(
    id::String;
    bench_handler::Union{Nothing,Function} = nothing,
    live_handler::Union{Nothing,Function} = nothing,
    live_triggers_render::Bool = !isnothing(live_handler),
)
    isnothing(live_handler) && live_triggers_render &&
        error("Action $(id) cannot trigger live renders without a live handler.")
    scopes = Set{Symbol}()
    isnothing(bench_handler) || push!(scopes, ACTION_SCOPE_BENCH)
    isnothing(live_handler) || push!(scopes, ACTION_SCOPE_LIVE)
    return ActionSpec(id, scopes, bench_handler, live_handler, live_triggers_render)
end

const ACTION_REGISTRY = Dict{String,ActionSpec}(
    "baseline" => _action_spec(
        "baseline";
        bench_handler = state -> nothing,
        live_handler = bindings -> nothing,
        live_triggers_render = false,
    ),
    "toggle_luminance_on" => _action_spec(
        "toggle_luminance_on";
        bench_handler = state -> set_term_enabled!(state, :luminance, true),
        live_handler = bindings -> set_live_term_enabled!(bindings, :luminance, true),
    ),
    "toggle_luminance_off" => _action_spec(
        "toggle_luminance_off";
        bench_handler = state -> set_term_enabled!(state, :luminance, false),
        live_handler = bindings -> set_live_term_enabled!(bindings, :luminance, false),
    ),
    "toggle_fruit_on" => _action_spec(
        "toggle_fruit_on";
        bench_handler = state -> set_term_enabled!(state, :fruit, true),
        live_handler = bindings -> set_live_term_enabled!(bindings, :fruit, true),
    ),
    "toggle_fruit_off" => _action_spec(
        "toggle_fruit_off";
        bench_handler = state -> set_term_enabled!(state, :fruit, false),
        live_handler = bindings -> set_live_term_enabled!(bindings, :fruit, false),
    ),
    "toggle_animal_on" => _action_spec(
        "toggle_animal_on";
        bench_handler = state -> set_term_enabled!(state, :animal, true),
        live_handler = bindings -> set_live_term_enabled!(bindings, :animal, true),
    ),
    "toggle_animal_off" => _action_spec(
        "toggle_animal_off";
        bench_handler = state -> set_term_enabled!(state, :animal, false),
        live_handler = bindings -> set_live_term_enabled!(bindings, :animal, false),
    ),
    "map_color_fruit" => _action_spec(
        "map_color_fruit";
        bench_handler = state -> set_mapping_slot!(state, :color, :fruit),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :color, :fruit),
    ),
    "map_color_animal" => _action_spec(
        "map_color_animal";
        bench_handler = state -> set_mapping_slot!(state, :color, :animal),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :color, :animal),
    ),
    "color_none" => _action_spec(
        "color_none";
        bench_handler = state -> set_mapping_slot!(state, :color, :none),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :color, :none),
    ),
    "map_marker_fruit" => _action_spec(
        "map_marker_fruit";
        bench_handler = state -> set_mapping_slot!(state, :marker, :fruit),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :marker, :fruit),
    ),
    "map_marker_animal" => _action_spec(
        "map_marker_animal";
        bench_handler = state -> set_mapping_slot!(state, :marker, :animal),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :marker, :animal),
    ),
    "marker_none" => _action_spec(
        "marker_none";
        bench_handler = state -> set_mapping_slot!(state, :marker, :none),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :marker, :none),
    ),
    "map_linestyle_fruit" => _action_spec(
        "map_linestyle_fruit";
        bench_handler = state -> set_mapping_slot!(state, :linestyle, :fruit),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :linestyle, :fruit),
    ),
    "map_linestyle_animal" => _action_spec(
        "map_linestyle_animal";
        bench_handler = state -> set_mapping_slot!(state, :linestyle, :animal),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :linestyle, :animal),
    ),
    "linestyle_none" => _action_spec(
        "linestyle_none";
        bench_handler = state -> set_mapping_slot!(state, :linestyle, :none),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :linestyle, :none),
    ),
    "facet_col_fruit" => _action_spec(
        "facet_col_fruit";
        bench_handler = state -> set_mapping_slot!(state, :col, :fruit),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :col, :fruit),
    ),
    "facet_col_animal" => _action_spec(
        "facet_col_animal";
        bench_handler = state -> set_mapping_slot!(state, :col, :animal),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :col, :animal),
    ),
    "facet_col_none" => _action_spec(
        "facet_col_none";
        bench_handler = state -> set_mapping_slot!(state, :col, :none),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :col, :none),
    ),
    "facet_row_fruit" => _action_spec(
        "facet_row_fruit";
        bench_handler = state -> set_mapping_slot!(state, :row, :fruit),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :row, :fruit),
    ),
    "facet_row_animal" => _action_spec(
        "facet_row_animal";
        bench_handler = state -> set_mapping_slot!(state, :row, :animal),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :row, :animal),
    ),
    "facet_row_none" => _action_spec(
        "facet_row_none";
        bench_handler = state -> set_mapping_slot!(state, :row, :none),
        live_handler = bindings -> set_live_mapping_slot!(bindings, :row, :none),
    ),
    "channel_1" => _action_spec(
        "channel_1";
        bench_handler = state -> set_bench_channel!(state, 1),
        live_handler = bindings -> set_live_channel!(bindings, 1),
    ),
    "channel_2" => _action_spec(
        "channel_2";
        bench_handler = state -> set_bench_channel!(state, 2),
        live_handler = bindings -> set_live_channel!(bindings, 2),
    ),
    "reset_view" => _action_spec(
        "reset_view";
        bench_handler = state -> nothing,
        live_handler = bindings -> trigger_live_reset!(bindings),
        live_triggers_render = false,
    ),
    "luminance_full_range" => _action_spec(
        "luminance_full_range";
        bench_handler = state -> begin
            set_term_enabled!(state, :luminance, true)
            set_continuous_range!(state, :luminance, [0.0, 100.0])
        end,
    ),
)

const DEFAULT_BENCH_ACTION_IDS = [
    "baseline",
    "toggle_luminance_on",
    "toggle_luminance_off",
    "toggle_fruit_on",
    "toggle_animal_on",
    "map_color_fruit",
    "map_marker_animal",
    "map_linestyle_animal",
    "facet_col_animal",
    "facet_row_animal",
    "color_none",
    "marker_none",
    "linestyle_none",
    "facet_col_none",
    "facet_row_none",
    "luminance_full_range",
]

"""
    action_registry()

Return the canonical action registry.
"""
action_registry() = ACTION_REGISTRY

"""
    registered_action_ids()

Return sorted registered action IDs.
"""
registered_action_ids() = sort!(collect(keys(ACTION_REGISTRY)))

"""
    action_ids_for_scope(scope)

Return sorted action IDs supporting the given scope (`:bench` or `:live`).
"""
function action_ids_for_scope(scope::Symbol)
    return sort!([
        id for (id, spec) in ACTION_REGISTRY if scope in spec.scopes
    ])
end

"""
    live_action_triggers_render(action_id)

Return whether a live-scope action is expected to trigger a plotted layout render.
"""
function live_action_triggers_render(action_id::String)
    spec = get(ACTION_REGISTRY, action_id, nothing)
    isnothing(spec) && error("Unknown action ID: $(action_id)")
    ACTION_SCOPE_LIVE in spec.scopes || error("Action $(action_id) has no live handler")
    return spec.live_triggers_render
end

"""
    default_bench_scenario()

Return the default offline bench action sequence.
"""
default_bench_scenario() = copy(DEFAULT_BENCH_ACTION_IDS)

"""
    ensure_registered_action_ids(ids; required_scope=nothing, source_label="")

Validate that action IDs exist in registry and optionally support a scope.
"""
function ensure_registered_action_ids(
    action_ids::Vector{String};
    required_scope::Union{Nothing,Symbol} = nothing,
    source_label::AbstractString = "",
)
    invalid_ids = [id for id in action_ids if !haskey(ACTION_REGISTRY, id)]
    if !isempty(invalid_ids)
        where_msg = isempty(source_label) ? "" : " in $(source_label)"
        error(
            "Unknown action ID(s)$(where_msg): $(join(invalid_ids, ", ")). Registered IDs: " *
            join(registered_action_ids(), ", "),
        )
    end

    if !isnothing(required_scope)
        missing_scope = [
            id for id in action_ids if !(required_scope in ACTION_REGISTRY[id].scopes)
        ]
        if !isempty(missing_scope)
            error(
                "Action ID(s) missing required scope $(required_scope): $(join(missing_scope, ", "))",
            )
        end
    end

    return nothing
end

"""
    apply_bench_action!(state, action_id)

Execute one bench-scope action against `BenchActionState`.
"""
function apply_bench_action!(state::BenchActionState, action_id::String)
    spec = get(ACTION_REGISTRY, action_id, nothing)
    isnothing(spec) && error("Unknown benchmark action ID: $(action_id)")
    isnothing(spec.apply_bench!) && error("Action $(action_id) has no bench handler")
    spec.apply_bench!(state)
    return nothing
end

"""
    apply_live_action!(bindings, action_id)

Execute one live-scope action against `LiveUiBindings`.
"""
function apply_live_action!(bindings::LiveUiBindings, action_id::String)
    spec = get(ACTION_REGISTRY, action_id, nothing)
    isnothing(spec) && error("Unknown live action ID: $(action_id)")
    isnothing(spec.apply_live!) && error("Action $(action_id) has no live handler")
    spec.apply_live!(bindings)
    return nothing
end
