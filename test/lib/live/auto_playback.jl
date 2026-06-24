"""
    LivePlaybackState

Mutable runtime state for auto live playback and timing/report collection.
"""
mutable struct LivePlaybackState
    action_ids::Vector{String}
    report_path::String
    start_delay_sec::Float64
    step_delay_sec::Float64
    action_timeout_sec::Float64
    render_settle_delay_sec::Float64
    rows::Vector{NamedTuple}
    pending_seq::Base.RefValue{Int}
    pending_source::Base.RefValue{String}
    pending_action_id::Base.RefValue{String}
    pending_start_ns::Base.RefValue{Int64}
    pending_effects_ms::Base.RefValue{Union{Nothing,Float64}}
    pending_plot_layout_ms::Base.RefValue{Union{Nothing,Float64}}
    pending_render_version::Base.RefValue{Int}
    pending_triggers_render::Base.RefValue{Bool}
    pending_record_row::Base.RefValue{Bool}
    action_completed::Base.RefValue{Bool}
    auto_action_inflight::Base.RefValue{Bool}
    auto_started::Base.RefValue{Bool}
    initial_render_ready::Base.RefValue{Bool}
    auto_completed::Base.RefValue{Int}
    auto_timed_out::Base.RefValue{Int}
    auto_failed::Base.RefValue{Int}
    report_written::Base.RefValue{Bool}
end

"""
    create_live_playback_state(config, action_ids, report_path)

Construct playback state for `bench-live-auto`.
"""
function create_live_playback_state(
    config::HarnessConfig,
    action_ids::Vector{String},
    report_path::AbstractString,
)
    return LivePlaybackState(
        action_ids,
        String(report_path),
        config.live_start_delay_sec,
        config.live_step_delay_sec,
        config.live_action_timeout_sec,
        DEFAULT_LIVE_RENDER_SETTLE_DELAY_SEC,
        NamedTuple[],
        Ref(0),
        Ref("init"),
        Ref(""),
        Ref(Int64(0)),
        Ref{Union{Nothing,Float64}}(nothing),
        Ref{Union{Nothing,Float64}}(nothing),
        Ref(0),
        Ref(false),
        Ref(true),
        Ref(true),
        Ref(false),
        Ref(false),
        Ref(false),
        Ref(0),
        Ref(0),
        Ref(0),
        Ref(false),
    )
end

function _live_effects_value(state::LivePlaybackState)
    return isnothing(state.pending_effects_ms[]) ? NaN : state.pending_effects_ms[]
end

function _live_plot_layout_value(state::LivePlaybackState)
    return isnothing(state.pending_plot_layout_ms[]) ? NaN : state.pending_plot_layout_ms[]
end

function _live_total_ms(state::LivePlaybackState)
    state.pending_start_ns[] <= 0 && return NaN
    return (time_ns() - state.pending_start_ns[]) / 1e6
end

function _append_live_row!(
    state::LivePlaybackState;
    effects_ms::Float64,
    plot_layout_ms::Float64,
    status::Symbol = :completed,
)
    state.action_completed[] && return false
    action_id = state.pending_action_id[]
    if state.pending_record_row[]
        push!(
            state.rows,
            (
                sequence = state.pending_seq[],
                event_source = state.pending_source[],
                action_id = action_id,
                effects_ms = effects_ms,
                plot_layout_ms = plot_layout_ms,
                total_ms = _live_total_ms(state),
            ),
        )
        if status == :completed
            state.auto_completed[] += 1
        elseif status == :timed_out
            state.auto_timed_out[] += 1
        elseif status == :failed
            state.auto_failed[] += 1
        else
            error("Unsupported live action row status $(repr(status)).")
        end
    end
    state.auto_action_inflight[] = false
    state.action_completed[] = true
    state.pending_start_ns[] = 0
    state.pending_record_row[] = true
    return true
end

"""
    begin_auto_action!(state, action_id, triggers_render; record_row = true)

Start timing one scripted live-auto action.
"""
function begin_auto_action!(
    state::LivePlaybackState,
    action_id::String,
    triggers_render::Bool,
    ;
    record_row::Bool = true,
)
    record_row && (state.pending_seq[] += 1)
    state.pending_source[] = "auto:" * action_id
    state.pending_action_id[] = action_id
    state.pending_start_ns[] = time_ns()
    state.pending_effects_ms[] = nothing
    state.pending_plot_layout_ms[] = nothing
    state.pending_render_version[] = 0
    state.pending_triggers_render[] = triggers_render
    state.pending_record_row[] = record_row
    state.action_completed[] = false
    state.auto_action_inflight[] = true
    return nothing
end

"""
    record_instant_action!(state)

Record a non-rendering live-auto action.
"""
function record_instant_action!(state::LivePlaybackState)
    return _append_live_row!(state; effects_ms = NaN, plot_layout_ms = NaN)
end

function _record_render_action!(state::LivePlaybackState)
    return _append_live_row!(
        state;
        effects_ms = _live_effects_value(state),
        plot_layout_ms = _live_plot_layout_value(state),
    )
end

function record_timed_out_action!(state::LivePlaybackState)
    return _append_live_row!(
        state;
        effects_ms = _live_effects_value(state),
        plot_layout_ms = _live_plot_layout_value(state),
        status = :timed_out,
    )
end

function record_failed_action!(state::LivePlaybackState)
    return _append_live_row!(
        state;
        effects_ms = _live_effects_value(state),
        plot_layout_ms = _live_plot_layout_value(state),
        status = :failed,
    )
end

function mark_initial_render_ready!(state::LivePlaybackState)
    state.initial_render_ready[] = true
    return nothing
end

live_auto_can_start(state::LivePlaybackState) =
    state.initial_render_ready[] && !state.auto_started[]

"""
    mark_pending_action!(state, source)

Mark the start of a manual action/timing source.
"""
function mark_pending_action!(state::LivePlaybackState, source::AbstractString)
    if state.auto_action_inflight[] &&
       startswith(state.pending_source[], "auto:") &&
       !startswith(source, "auto:")
        return
    end

    state.pending_seq[] += 1
    state.pending_source[] = String(source)
    state.pending_action_id[] = ""
    state.pending_start_ns[] = time_ns()
    state.pending_effects_ms[] = nothing
    state.pending_plot_layout_ms[] = nothing
    state.pending_render_version[] = 0
    state.pending_triggers_render[] = true
    state.action_completed[] = false
    return
end

"""
    mark_effects_ready!(state, effects_ms)

Record measured effects computation duration for the current pending event.
"""
function mark_effects_ready!(state::LivePlaybackState, effects_ms::Union{Nothing,Float64})
    if state.pending_start_ns[] > 0
        state.pending_effects_ms[] = effects_ms
    end
    return
end

function _write_live_report_once!(state::LivePlaybackState)
    if state.report_written[]
        return
    end

    mkpath(dirname(state.report_path))
    write_live_csv(state.report_path, state.rows)
    state.report_written[] = true
end

"""
    schedule_render_settle!(state, plot_layout_ms)

Record the latest render timing and commit it after a short quiet period.
"""
function schedule_render_settle!(state::LivePlaybackState, plot_layout_ms::Float64)
    state.pending_plot_layout_ms[] = plot_layout_ms
    state.pending_render_version[] += 1
    version = state.pending_render_version[]
    seq = state.pending_seq[]
    source = state.pending_source[]

    @async begin
        sleep(state.render_settle_delay_sec)
        if state.pending_seq[] == seq &&
           state.pending_source[] == source &&
           state.pending_render_version[] == version &&
           state.auto_action_inflight[] &&
           !state.action_completed[]
            _record_render_action!(state)
        end
    end

    return nothing
end

"""
    wait_for_action_completion!(state, timeout_sec)

Wait until the current auto action is recorded. On timeout, write a row with
the latest available timings and return `false`.
"""
function wait_for_action_completion!(state::LivePlaybackState, timeout_sec::Float64)
    deadline = time() + timeout_sec
    while !state.action_completed[] && time() < deadline
        sleep(0.05)
    end
    state.action_completed[] && return true

    println(
        "auto-livebench action timed out: ",
        state.pending_action_id[],
        " after ",
        round(timeout_sec; digits = 2),
        "s",
    )
    record_timed_out_action!(state)
    return false
end

is_closed_render_error(err_msg::AbstractString) =
    occursin("Screen Session uninitialized", err_msg) ||
    occursin("Session status: SOFT_CLOSED", err_msg)

is_render_transport_timeout(err_msg::AbstractString) = occursin("Timed out", err_msg)

function record_render_transport_timeout!(state::LivePlaybackState, err_msg::AbstractString)
    println(
        "auto-livebench render transport timed out: ",
        state.pending_action_id[],
        " :: ",
        split(err_msg, '\n')[1],
    )
    return record_timed_out_action!(state)
end

function handle_live_render_error!(state::LivePlaybackState, err_msg::AbstractString)
    is_closed_render_error(err_msg) && return :closed
    if is_render_transport_timeout(err_msg) && state.auto_started[]
        if state.auto_action_inflight[] &&
           startswith(state.pending_source[], "auto:") &&
           !state.action_completed[]
            record_render_transport_timeout!(state, err_msg)
        else
            println(
                "auto-livebench render transport timed out after pending action was already handled: ",
                split(err_msg, '\n')[1],
            )
        end
        return :timeout
    end
    return :rethrow
end

"""
    maybe_start_auto_playback!(state, bindings, scenario_path)

Start async auto playback once.
"""
const LIVE_WARMUP_ACTION_IDS = ("channel_2", "channel_1")

function run_live_warmup!(state::LivePlaybackState, bindings::LiveUiBindings)
    println("auto-livebench: warming up browser render path")
    for action_id in LIVE_WARMUP_ACTION_IDS
        triggers_render = live_action_triggers_render(action_id)
        println("auto-livebench warmup action: ", action_id)
        begin_auto_action!(state, action_id, triggers_render; record_row = false)
        try
            apply_live_action!(bindings, action_id)
        catch err
            println("auto-livebench warmup failed: ", action_id, " :: ", sprint(showerror, err))
            record_failed_action!(state)
        end

        if !triggers_render && !state.action_completed[]
            record_instant_action!(state)
        end

        wait_for_action_completion!(state, state.action_timeout_sec)
        sleep(state.render_settle_delay_sec)
    end
    println("auto-livebench: warmup complete")
    return nothing
end

function maybe_start_auto_playback!(
    state::LivePlaybackState,
    bindings::LiveUiBindings,
    scenario_path::AbstractString,
)
    if !live_auto_can_start(state)
        return
    end
    state.auto_started[] = true

    @async begin
        sleep(state.start_delay_sec)
        run_live_warmup!(state, bindings)
        println("auto-livebench: starting ", length(state.action_ids), " actions")
        println("auto-livebench: action file = ", scenario_path)
        println("auto-livebench: report file = ", state.report_path)

        timeout_sec = state.action_timeout_sec
        for (ix, action_id) in enumerate(state.action_ids)
            triggers_render = live_action_triggers_render(action_id)
            println("auto-livebench action: ", action_id)
            begin_auto_action!(state, action_id, triggers_render)

            try
                apply_live_action!(bindings, action_id)
            catch err
                println("auto-livebench action failed: ", action_id, " :: ", sprint(showerror, err))
                record_failed_action!(state)
            end

            if !triggers_render && !state.action_completed[]
                record_instant_action!(state)
            end

            wait_for_action_completion!(state, timeout_sec)
            if ix < length(state.action_ids)
                sleep(state.step_delay_sec)
            end
        end

        if !state.report_written[]
            _write_live_report_once!(state)
            totals = [row.total_ms for row in state.rows]
            median_total = isempty(totals) ? NaN : median(totals)
            println(
                "auto-livebench summary: actions=",
                length(state.rows),
                " completed=",
                state.auto_completed[],
                " timed_out=",
                state.auto_timed_out[],
                " failed=",
                state.auto_failed[],
                " median_total_ms=",
                round(median_total; digits = 2),
            )
            println("auto-livebench report: ", state.report_path)
        end
        println("auto-livebench: done")
    end

    return
end

"""
    on_render_completed!(state, plot_layout_ms)

Handle post-render timing, logging, and report row accumulation.
"""
function on_render_completed!(state::LivePlaybackState, plot_layout_ms::Float64)
    if state.pending_start_ns[] <= 0
        return
    end

    total_ms = _live_total_ms(state)
    effects_value = _live_effects_value(state)
    effects_text = isnan(effects_value) ? "n/a" : @sprintf("%.2f", effects_value)

    if state.pending_record_row[]
        println(
            "livebench #",
            state.pending_seq[],
            " source=",
            state.pending_source[],
            " effects_ms=",
            effects_text,
            " plot_layout_ms=",
            round(plot_layout_ms; digits = 2),
            " total_ms=",
            round(total_ms; digits = 2),
        )
    end

    if startswith(state.pending_source[], "auto:")
        schedule_render_settle!(state, plot_layout_ms)
    else
        state.pending_start_ns[] = 0
        state.action_completed[] = true
    end

    return
end
