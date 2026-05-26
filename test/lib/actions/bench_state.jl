"""
    BenchActionState

Mutable state used by offline benchmark action replay.
"""
mutable struct BenchActionState
    active_terms::Dict{Symbol,Bool}
    selected_values::Dict{Symbol,Any}
    term_types::Dict{Symbol,Symbol}
    mapping::Dict{Symbol,Symbol}
    channel::Base.RefValue{Int}
end

"""
    initialize_bench_state(variables, channel)

Create the benchmark action state from extracted model variables.
"""
function initialize_bench_state(variables, channel::Int)
    selected_values = Dict{Symbol,Any}()
    active_terms = Dict{Symbol,Bool}()
    term_types = Dict{Symbol,Symbol}()

    for (term, info) in variables
        term_type = info[3]
        term_values = info[4]
        active_terms[term] = false
        term_types[term] = term_type

        if term_type == :CategoricalTerm
            selected_values[term] = collect(term_values)
        elseif ERPExplorer.is_continuous_like(term_type)
            selected_values[term] = [Float64(term_values.min), Float64(term_values.max)]
        end
    end

    mapping = Dict(
        :color => :none,
        :marker => :none,
        :linestyle => :none,
        :col => :none,
        :row => :none,
    )

    return BenchActionState(active_terms, selected_values, term_types, mapping, Ref(channel))
end

"""
    set_term_enabled!(state, term, enabled)

Enable or disable a model term.
"""
function set_term_enabled!(state::BenchActionState, term::Symbol, enabled::Bool)
    haskey(state.active_terms, term) || return
    state.active_terms[term] = enabled
    return nothing
end

"""
    set_mapping_slot!(state, slot, value)

Set a visual mapping slot (`:color`, `:marker`, `:linestyle`, `:row`, `:col`).
"""
function set_mapping_slot!(state::BenchActionState, slot::Symbol, value::Symbol)
    state.mapping[slot] = value
    return nothing
end

"""
    set_bench_channel!(state, channel)

Select channel index for effects filtering.
"""
function set_bench_channel!(state::BenchActionState, channel::Int)
    state.channel[] = channel
    return nothing
end

"""
    set_continuous_range!(state, term, range_values)

Assign explicit continuous range values for a term.
"""
function set_continuous_range!(state::BenchActionState, term::Symbol, range_values::Vector{Float64})
    state.selected_values[term] = range_values
    return nothing
end
