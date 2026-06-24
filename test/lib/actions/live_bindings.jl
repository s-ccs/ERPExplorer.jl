"""
    LiveUiBindings

Imperative control adapters for live benchmark action replay.
"""
struct LiveUiBindings
    set_term_enabled!::Function
    set_mapping_slot!::Function
    set_channel!::Function
    reset_view!::Function
end

"""
    set_live_term_enabled!(bindings, term, enabled)

Set checkbox-like term toggle in the live UI.
"""
function set_live_term_enabled!(bindings::LiveUiBindings, term::Symbol, enabled::Bool)
    bindings.set_term_enabled!(term, enabled)
    return nothing
end

"""
    set_live_mapping_slot!(bindings, slot, value)

Set a dropdown mapping slot in the live UI.
"""
function set_live_mapping_slot!(bindings::LiveUiBindings, slot::Symbol, value::Symbol)
    bindings.set_mapping_slot!(slot, value)
    return nothing
end

"""
    set_live_channel!(bindings, channel)

Set selected channel in the live UI.
"""
function set_live_channel!(bindings::LiveUiBindings, channel::Int)
    bindings.set_channel!(channel)
    return nothing
end

"""
    trigger_live_reset!(bindings)

Trigger the live UI reset-view action.
"""
function trigger_live_reset!(bindings::LiveUiBindings)
    bindings.reset_view!()
    return nothing
end
