#!/usr/bin/env julia
import Pkg
using Printf
using Dates

const ERP_PATH = "/home/svennaber/Documents/SSCS_vis/ERPExplorer.jl"
const HOST = "127.0.0.1"
const PORT = 8082
const SFREQ = 100

function parse_cli(args)
    opts = Dict{String,String}()
    flags = Set{String}()
    for arg in args
        if startswith(arg, "--")
            kv = split(arg[3:end], "="; limit = 2)
            if length(kv) == 2
                opts[kv[1]] = kv[2]
            else
                push!(flags, kv[1])
            end
        end
    end
    return opts, flags
end

const CLI_OPTS, CLI_FLAGS = parse_cli(ARGS)
const BENCH_MODE = ("bench" in CLI_FLAGS) || (get(CLI_OPTS, "mode", "serve") == "bench")
const BENCH_LIVE_AUTO =
    ("bench-live-auto" in CLI_FLAGS) || (get(CLI_OPTS, "mode", "serve") == "bench-live-auto")
const BENCH_LIVE =
    ("bench-live" in CLI_FLAGS) || (get(CLI_OPTS, "mode", "serve") == "bench-live") || BENCH_LIVE_AUTO
const BENCH_REPEATS = parse(Int, get(CLI_OPTS, "bench-repeats", "5"))
const BENCH_WARMUP = parse(Int, get(CLI_OPTS, "bench-warmup", "1"))
const BENCH_CHANNEL = parse(Int, get(CLI_OPTS, "bench-channel", "1"))
const BENCH_OUT = get(CLI_OPTS, "bench-out", "")
const BENCH_LIVE_START_DELAY = parse(Float64, get(CLI_OPTS, "bench-live-start-delay", "20"))
const BENCH_LIVE_DELAY = max(5.0, parse(Float64, get(CLI_OPTS, "bench-live-delay", "5")))
const DEFAULT_LIVE_ACTIONS_FILE = joinpath(@__DIR__, "livebench_actions_default.txt")
const ALL_LIVE_ACTIONS_FILE = joinpath(@__DIR__, "livebench_actions_all.txt")
const BENCH_LIVE_ACTIONS_FILE = get(CLI_OPTS, "bench-live-actions", DEFAULT_LIVE_ACTIONS_FILE)
const BENCH_LIVE_REPORT = get(CLI_OPTS, "bench-live-report", "")

# Use a persistent environment next to this script
const ENV_DIR = joinpath(@__DIR__, ".erp_env")
Pkg.activate(ENV_DIR)
Pkg.develop(url="https://github.com/MakieOrg/AlgebraOfGraphics.jl")
Pkg.develop(path=ERP_PATH)

Pkg.add([
    "Unfold",
    "UnfoldSim",
    "DataFrames",
    "Random",
    "GeometryBasics",
    "TopoPlots",
    "Bonito",
    "WGLMakie",
    "Makie",
])
Pkg.instantiate()

using Random, DataFrames
using GeometryBasics
using Unfold, UnfoldSim
using Makie, WGLMakie
using Bonito
using TopoPlots
using ERPExplorer
using Statistics

# --- your generator (unchanged) ---
function gen_data(n_channels = 64)
    d1, evts = UnfoldSim.predef_eeg(n_repeats = 120, noiselevel = 25; return_epoched = true)
    n_timepoints = size(d1, 1)

    dataS = [
        d1 .+
        3 * sin.(0.1 * pi * i .+ rand() * 2π) .+
        2 * sin.(0.3 * pi * i .* (1:n_timepoints)) .+
        randn(size(d1)) .* 5 .+
        circshift(d1, rand(-10:10)) .* 0.2
        for i = 1:n_channels
    ]
    dataS = permutedims(cat(dataS..., dims = 3), (3, 1, 2))
    dataS = dataS .+ rand(dataS)

    evts = insertcols(
        evts,
        :saccade_amplitude => rand(nrow(evts)) .* 15,
        :luminance => rand(nrow(evts)) .* 100,
        :contrast => rand(nrow(evts)),
        :string => shuffle(
            repeat(
                ["stringsuperlong", "stringshort", "stringUPPERCASE", "stringEXCITED!!!!"],
                outer = div(nrow(evts), 4),
            ),
        ),
        :animal => shuffle(repeat(["cat", "dog"], outer = div(nrow(evts), 2))),
        :fruit => shuffle(repeat(["orange", "banana"], outer = div(nrow(evts), 2))),
        :color => shuffle(repeat(["black", "white"], outer = div(nrow(evts), 2))),
    )

    positions = rand(Point2f, size(dataS, 1))
    return dataS, evts, positions
end

# --- simulate + fit ---
dataS, evts, _positions = gen_data()
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)

# Times length must match the 2nd last dimension of dataS
times = range(0, length = size(dataS, 2), step = 1 / SFREQ)

model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
_, topo_example_positions = TopoPlots.example_data()
half_positions = topo_example_positions[1:2:end]
positions_sets = Dict(
    "TopoPlots example" => topo_example_positions,
    "TopoPlots example (half)" => half_positions,
)

# --- serve it (serve the explorer_app directly; don't wrap it) ---
function start_server(app; host = HOST, port = PORT)
    if isdefined(Bonito, :Server)
        server = Bonito.Server(app, host, port)
        println("Open: http://$(host):$(port)")
        return server
    elseif isdefined(Bonito, :serve)
        url = Bonito.serve(app; host = host, port = port)
        println("Open: ", url)
        return nothing
    else
        error("No Bonito.Server or Bonito.serve found in this Bonito version.")
    end
end

function write_bench_csv(path, rows)
    open(path, "w") do io
        println(io, "step,ok,successful_runs,repeats,effects_ms,update_grid_ms,total_ms,error")
        for r in rows
            err = replace(r.error, '\n' => ' ')
            err = replace(err, '"' => '\'')
            println(
                io,
                string(
                    r.step, ",",
                    r.ok, ",",
                    r.successful_runs, ",",
                    r.repeats, ",",
                    r.effects_ms, ",",
                    r.grid_ms, ",",
                    r.total_ms, ",\"",
                    err, "\"",
                ),
            )
        end
    end
end

function default_livebench_report_path(actions_path::AbstractString)
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    actions_abs = abspath(actions_path)
    actions_dir = dirname(actions_abs)
    actions_stem = splitext(basename(actions_abs))[1]
    return joinpath(actions_dir, "$(actions_stem)_report_$(timestamp).csv")
end

function read_livebench_action_names(path::AbstractString)
    if !isfile(path)
        error("Live benchmark action file not found: $(path)")
    end
    names = String[]
    for (line_no, raw_line) in enumerate(eachline(path))
        line = strip(split(raw_line, '#'; limit = 2)[1])
        isempty(line) && continue
        push!(names, line)
    end
    isempty(names) && error("No actions found in live benchmark action file: $(path)")
    return names
end

function write_livebench_csv(path::AbstractString, rows)
    open(path, "w") do io
        println(io, "seq,source,action,effects_ms,layout_ms,total_ms")
        for r in rows
            println(
                io,
                string(
                    r.seq, ",",
                    r.source, ",",
                    r.action, ",",
                    r.effects_ms, ",",
                    r.layout_ms, ",",
                    r.total_ms,
                ),
            )
        end
    end
end

function run_action_bench(model; repeats = 5, warmup = 1, channel = 1, out_csv = "")
    variables = ERPExplorer.extract_variables(model)
    formula_values = [k => ERPExplorer.value_range(v) for (k, v) in variables]
    var_types = map(x -> x[2][3], variables)
    var_names = first.(variables)
    cat_terms = var_names[var_types .== :CategoricalTerm]
    cont_terms = var_names[var_types .== :ContinuousTerm]

    selected = Dict{Symbol,Any}()
    active = Dict{Symbol,Bool}()
    for (k, info) in variables
        typ = info[3]
        vals = info[4]
        active[k] = false
        if typ == :CategoricalTerm
            selected[k] = collect(vals)
        elseif typ == :ContinuousTerm || typ == :BSplineTerm
            selected[k] = [Float64(vals.min), Float64(vals.max)]
        end
    end

    mapping = Dict(
        :color => :none,
        :marker => :none,
        :linestyle => :none,
        :col => :none,
        :row => :none,
    )

    function make_erp_data()
        yhat_dict = Dict{Symbol,Any}()
        for (k, on) in active
            if on
                yhat_dict[k] = ERPExplorer.widget_value(selected[k])
            end
        end
        if isempty(yhat_dict)
            yhat_dict = Dict(:dummy => ["dummy"])
        end

        yhats = effects(yhat_dict, model)
        for (k, on) in active
            if !on
                yhats[!, k] .= "typical_value"
            end
        end
        filter!(x -> x.channel == channel, yhats)
        return yhats
    end

    function run_once()
        t0 = time_ns()
        t1 = time_ns()
        yhats = make_erp_data()
        effects_ms = (time_ns() - t1) / 1e6
        t2 = time_ns()
        ERPExplorer.update_grid(yhats, formula_values, cat_terms, cont_terms, mapping)
        grid_ms = (time_ns() - t2) / 1e6
        total_ms = (time_ns() - t0) / 1e6
        return effects_ms, grid_ms, total_ms
    end

    actions = [
        ("baseline", () -> nothing),
        ("toggle_luminance_on", () -> (active[:luminance] = true)),
        ("toggle_luminance_off", () -> (active[:luminance] = false)),
        ("toggle_fruit_on", () -> (active[:fruit] = true)),
        ("toggle_animal_on", () -> (active[:animal] = true)),
        ("map_color_fruit", () -> (mapping[:color] = :fruit)),
        ("map_marker_animal", () -> (mapping[:marker] = :animal)),
        ("map_linestyle_animal", () -> (mapping[:linestyle] = :animal)),
        ("facet_col_animal", () -> (mapping[:col] = :animal)),
        ("facet_row_animal", () -> (mapping[:row] = :animal)),
        ("color_none", () -> (mapping[:color] = :none)),
        ("marker_none", () -> (mapping[:marker] = :none)),
        ("linestyle_none", () -> (mapping[:linestyle] = :none)),
        ("facet_col_none", () -> (mapping[:col] = :none)),
        ("facet_row_none", () -> (mapping[:row] = :none)),
        ("luminance_full_range", () -> begin
            active[:luminance] = true
            selected[:luminance] = [0.0, 100.0]
        end),
    ]

    for _ = 1:warmup
        run_once()
    end

    rows = NamedTuple[]
    println("Running GUI-action benchmark")
    println("repeats=$(repeats), warmup=$(warmup), channel=$(channel)")
    println(rpad("step", 28), rpad("ok", 6), rpad("n", 6), rpad("effects", 12), rpad("grid", 12), "total")
    println(repeat("-", 74))
    for (step_name, apply_step!) in actions
        apply_step!()
        ok = true
        err = ""
        effects_samples = Float64[]
        grid_samples = Float64[]
        total_samples = Float64[]
        successful_runs = 0
        for _ = 1:repeats
            try
                effects_ms, grid_ms, total_ms = run_once()
                push!(effects_samples, effects_ms)
                push!(grid_samples, grid_ms)
                push!(total_samples, total_ms)
                successful_runs += 1
            catch e
                ok = false
                err = sprint(showerror, e, catch_backtrace())
                break
            end
        end
        if ok
            eff = median(effects_samples)
            grd = median(grid_samples)
            tot = median(total_samples)
            push!(
                rows,
                (
                    step = step_name,
                    ok = true,
                    successful_runs = successful_runs,
                    repeats = repeats,
                    effects_ms = eff,
                    grid_ms = grd,
                    total_ms = tot,
                    error = "",
                ),
            )
            @printf("%-28s %-6s %-6d %9.2fms %9.2fms %9.2fms\n", step_name, "true", successful_runs, eff, grd, tot)
        else
            push!(
                rows,
                (
                    step = step_name,
                    ok = false,
                    successful_runs = successful_runs,
                    repeats = repeats,
                    effects_ms = NaN,
                    grid_ms = NaN,
                    total_ms = NaN,
                    error = err,
                ),
            )
            @printf("%-28s %-6s %-6d %9s   %9s   %9s\n", step_name, "false", successful_runs, "ERR", "ERR", "ERR")
            println("  error: ", split(err, '\n')[1])
        end
    end

    if !isempty(out_csv)
        mkpath(dirname(out_csv))
        write_bench_csv(out_csv, rows)
        println("Wrote benchmark CSV: ", out_csv)
    end
end

function mapping_dropdowns_with_handles(var_names, var_types)
    cats = [v for (ix, v) in enumerate(var_names) if var_types[ix] == :CategoricalTerm]
    push!(cats, :none)

    c_dropdown = Dropdown(cats; index = length(cats))
    m_dropdown = Dropdown(cats; index = length(cats))
    l_dropdown = Dropdown(cats; index = length(cats))
    col_dropdown = Dropdown(cats; index = length(cats))
    row_dropdown = Dropdown(cats; index = length(cats))

    mapping = @lift Dict(
        :color => $(c_dropdown.value),
        :marker => $(m_dropdown.value),
        :linestyle => $(l_dropdown.value),
        :col => $(col_dropdown.value),
        :row => $(row_dropdown.value),
    )
    mapping_dom = Col(
        Row(DOM.div("color:"), c_dropdown, align_items = "center", justify_items = "end"),
        Row(DOM.div("marker:"), m_dropdown, align_items = "center", justify_items = "end"),
        Row(DOM.div("linestyle:"), l_dropdown, align_items = "center", justify_items = "end"),
        Row(DOM.div("column facet"), col_dropdown, align_items = "center", justify_items = "end"),
        Row(DOM.div("row facet"), row_dropdown, align_items = "center", justify_items = "end"),
    )
    controls = Dict(
        :color => c_dropdown,
        :marker => m_dropdown,
        :linestyle => l_dropdown,
        :col => col_dropdown,
        :row => row_dropdown,
    )
    return mapping, mapping_dom, controls
end

function build_live_bench_app(model; positions = nothing, size = (700, 600), fit_window = true)
    Bonito.set_cleanup_time!(1)
    return App() do
        variables = ERPExplorer.extract_variables(model)
        formula_defaults, formula_toggle, formula_DOM, formula_values =
            ERPExplorer.formular_widgets(variables)
        reset_button = Bonito.Button(
            "Reset view";
            style = Styles(
                "padding" => "4px 6px",
                "min-height" => "24px",
            ),
        )

        var_types = map(x -> x[2][3], variables)
        var_names = first.(variables)
        cat_terms = var_names[var_types .== :CategoricalTerm]
        cont_terms = var_names[var_types .== :ContinuousTerm]

        mapping, mapping_dom, mapping_controls = mapping_dropdowns_with_handles(var_names, var_types)

        channel_chosen = Observable(1)
        topo_widget = nothing
        topo_size = size .* 0.5
        if positions isa AbstractDict || positions isa NamedTuple
            pos_sets = Dict{String,Any}()
            for (k, v) in pairs(positions)
                pos_sets[string(k)] = v
            end
            pos_keys = collect(keys(pos_sets))
            topo_select = Dropdown(pos_keys; index = 1)
            topo_widget_obs =
                Observable{Any}(ERPExplorer.topoplot_widget(pos_sets[pos_keys[1]], channel_chosen; size = topo_size))
            on(topo_select.value) do key
                channel_chosen[] = 1
                topo_widget_obs[] =
                    ERPExplorer.topoplot_widget(pos_sets[key], channel_chosen; size = topo_size)
            end
            topo_widget = Col(
                Row(DOM.div("Topoplot:"), topo_select, align_items = "center"),
                topo_widget_obs,
            )
        elseif isnothing(positions)
            topo_widget = nothing
        else
            topo_widget = ERPExplorer.topoplot_widget(positions, channel_chosen; size = topo_size)
        end

        ERP_data = Observable{Any}(nothing; ignore_equal_values = true)
        last_effects_ms = Ref{Union{Nothing,Float64}}(nothing)
        onany(formula_toggle, channel_chosen; update = true) do formula_toggle_on, chan
            t0 = time_ns()
            yhat_dict = Dict{Symbol,Any}()
            for (k, v) in formula_toggle_on
                if !isempty(v) && v[1]
                    yhat_dict[k] = ERPExplorer.widget_value(v[2])
                end
            end
            if isempty(yhat_dict)
                yhat_dict = Dict(:dummy => ["dummy"])
            end
            yhats = effects(yhat_dict, model)
            for (k, wv) in formula_toggle_on
                if isempty(wv[2]) || !wv[1]
                    yhats[!, k] .= "typical_value"
                end
            end
            filter!(x -> x.channel == chan, yhats)
            last_effects_ms[] = (time_ns() - t0) / 1e6
            ERP_data[] = yhats
        end

        pending_seq = Ref(0)
        pending_source = Ref("init")
        pending_start_ns = Ref(Int64(0))
        pending_effects_ms = Ref{Union{Nothing,Float64}}(nothing)
        auto_action_inflight = Ref(false)
        function mark_action!(source::AbstractString)
            if auto_action_inflight[] &&
               startswith(pending_source[], "auto:") &&
               !startswith(source, "auto:")
                return
            end
            pending_seq[] += 1
            pending_source[] = source
            pending_start_ns[] = time_ns()
            pending_effects_ms[] = nothing
        end

        function set_checkbox!(name::Symbol, enabled::Bool)
            if haskey(formula_defaults, name)
                formula_defaults[name][] = enabled
            end
        end
        function set_dropdown!(target::Symbol, value::Symbol)
            if haskey(mapping_controls, target)
                mapping_controls[target].value[] = value
            end
        end
        function click_reset!()
            reset_button.value[] = !to_value(reset_button.value)
        end

        auto_started = Ref(false)
        available_auto_actions = Dict(
            "toggle_luminance_on" => () -> set_checkbox!(:luminance, true),
            "toggle_luminance_off" => () -> set_checkbox!(:luminance, false),
            "toggle_fruit_on" => () -> set_checkbox!(:fruit, true),
            "toggle_fruit_off" => () -> set_checkbox!(:fruit, false),
            "toggle_animal_on" => () -> set_checkbox!(:animal, true),
            "toggle_animal_off" => () -> set_checkbox!(:animal, false),
            "map_color_fruit" => () -> set_dropdown!(:color, :fruit),
            "map_color_animal" => () -> set_dropdown!(:color, :animal),
            "color_none" => () -> set_dropdown!(:color, :none),
            "map_marker_fruit" => () -> set_dropdown!(:marker, :fruit),
            "map_marker_animal" => () -> set_dropdown!(:marker, :animal),
            "marker_none" => () -> set_dropdown!(:marker, :none),
            "map_linestyle_fruit" => () -> set_dropdown!(:linestyle, :fruit),
            "map_linestyle_animal" => () -> set_dropdown!(:linestyle, :animal),
            "linestyle_none" => () -> set_dropdown!(:linestyle, :none),
            "facet_col_fruit" => () -> set_dropdown!(:col, :fruit),
            "facet_col_animal" => () -> set_dropdown!(:col, :animal),
            "facet_col_none" => () -> set_dropdown!(:col, :none),
            "facet_row_fruit" => () -> set_dropdown!(:row, :fruit),
            "facet_row_animal" => () -> set_dropdown!(:row, :animal),
            "facet_row_none" => () -> set_dropdown!(:row, :none),
            "channel_2" => () -> (channel_chosen[] = 2),
            "channel_1" => () -> (channel_chosen[] = 1),
            "reset_view" => click_reset!,
        )
        auto_action_names = BENCH_LIVE_AUTO ? read_livebench_action_names(BENCH_LIVE_ACTIONS_FILE) : String[]
        invalid_auto_actions = [n for n in auto_action_names if !haskey(available_auto_actions, n)]
        if !isempty(invalid_auto_actions)
            error(
                "Unknown auto actions in $(BENCH_LIVE_ACTIONS_FILE): $(join(invalid_auto_actions, ", ")). " *
                "See $(ALL_LIVE_ACTIONS_FILE) for supported names.",
            )
        end
        auto_actions = [
            (name, available_auto_actions[name]) for name in auto_action_names
        ]
        auto_rows = NamedTuple[]
        auto_completed = Ref(0)
        auto_report_written = Ref(false)
        auto_report_path =
            isempty(BENCH_LIVE_REPORT) ? default_livebench_report_path(BENCH_LIVE_ACTIONS_FILE) :
            BENCH_LIVE_REPORT
        function maybe_start_auto!()
            if !BENCH_LIVE_AUTO || auto_started[]
                return
            end
            auto_started[] = true
            @async begin
                sleep(BENCH_LIVE_START_DELAY)
                println("auto-livebench: starting ", length(auto_actions), " actions")
                println("auto-livebench: action file = ", BENCH_LIVE_ACTIONS_FILE)
                println("auto-livebench: report file = ", auto_report_path)
                for (name, act!) in auto_actions
                    println("auto-livebench action: ", name)
                    auto_action_inflight[] = true
                    mark_action!("auto:" * name)
                    try
                        act!()
                    catch err
                        auto_action_inflight[] = false
                        println("auto-livebench action failed: ", name, " :: ", sprint(showerror, err))
                    end
                    sleep(BENCH_LIVE_DELAY)
                end
                timeout_seconds = max(10.0, BENCH_LIVE_DELAY * (length(auto_actions) + 2))
                deadline = time() + timeout_seconds
                while auto_completed[] < length(auto_actions) && time() < deadline
                    sleep(0.1)
                end
                if !auto_report_written[]
                    mkpath(dirname(auto_report_path))
                    write_livebench_csv(auto_report_path, auto_rows)
                    auto_report_written[] = true
                    println(
                        "auto-livebench: done (partial) ",
                        auto_completed[],
                        "/",
                        length(auto_actions),
                        " actions rendered",
                    )
                    println("auto-livebench report: ", auto_report_path)
                else
                    println("auto-livebench: done")
                end
            end
        end

        formula_seen = Ref(false)
        syncing_formula_defaults = Ref(false)
        on(formula_toggle) do _
            if !formula_seen[]
                formula_seen[] = true
                return
            end
            if syncing_formula_defaults[]
                return
            end
            mark_action!("formula")
        end

        channel_seen = Ref(false)
        on(channel_chosen) do _
            if !channel_seen[]
                channel_seen[] = true
                return
            end
            mark_action!("topoplot")
        end

        mapping_seen = Ref(false)
        on(mapping) do m
            if mapping_seen[]
                mark_action!("mapping")
            else
                mapping_seen[] = true
            end
            syncing_formula_defaults[] = true
            try
                selected_terms = Set(v for v in values(m) if v != :none)
                for (term, toggle_obs) in formula_defaults
                    if term in selected_terms && !toggle_obs[]
                        toggle_obs[] = true
                    end
                end
            finally
                syncing_formula_defaults[] = false
            end
        end

        on(ERP_data) do yhats
            if pending_start_ns[] > 0 && yhats !== nothing
                pending_effects_ms[] = last_effects_ms[]
            end
            maybe_start_auto!()
        end

        plot_layout = Observable(ERPExplorer.S.GridLayout())
        lk = Base.ReentrantLock()
        auto_reset_view = true
        fig_ref = Ref{Union{Nothing,Makie.FigureAxisPlot}}(nothing)

        function reset_all_axes!()
            fig_obj = fig_ref[]
            isnothing(fig_obj) && return
            lock(lk) do
                function collect_axes!(acc, item)
                    if item isa Makie.Axis
                        push!(acc, item)
                    elseif item isa Makie.GridLayoutBase.GridLayout
                        for child in Makie.GridLayoutBase.contents(item)
                            collect_axes!(acc, child)
                        end
                    end
                end

                axes = Makie.Axis[]
                collect_axes!(axes, fig_obj.figure.layout)
                for ax in axes
                    Makie.reset_limits!(ax)
                    Makie.autolimits!(ax)
                end
            end
        end

        render_count = Ref(0)
        Makie.onany_latest(ERP_data, mapping; update = true) do ERP_data_val, mapping_val
            lock(lk) do
                t0 = time_ns()
                _tmp = ERPExplorer.update_grid(
                    ERP_data_val,
                    formula_values,
                    cat_terms,
                    cont_terms,
                    mapping_val,
                )
                try
                    plot_layout[] = _tmp
                catch err
                    err_msg = sprint(showerror, err)
                    if occursin("Screen Session uninitialized", err_msg) ||
                       occursin("Session status: SOFT_CLOSED", err_msg)
                        return
                    end
                    rethrow(err)
                end
                render_count[] += 1
                layout_ms = (time_ns() - t0) / 1e6
                println(
                    "render #",
                    render_count[],
                    " update_grid -> layout in ",
                    round(layout_ms; digits = 2),
                    " ms",
                )
                maybe_start_auto!()
                if auto_reset_view
                    reset_all_axes!()
                end
                if pending_start_ns[] > 0
                    total_ms = (time_ns() - pending_start_ns[]) / 1e6
                    effects_value = isnothing(pending_effects_ms[]) ? NaN : pending_effects_ms[]
                    effects_text = isnan(effects_value) ? "n/a" : @sprintf("%.2f", effects_value)
                    println(
                        "livebench #",
                        pending_seq[],
                        " source=",
                        pending_source[],
                        " effects_ms=",
                        effects_text,
                        " layout_ms=",
                        round(layout_ms; digits = 2),
                        " total_ms=",
                        round(total_ms; digits = 2),
                    )
                    if startswith(pending_source[], "auto:")
                        action_name = pending_source[][6:end]
                        push!(
                            auto_rows,
                            (
                                seq = pending_seq[],
                                source = pending_source[],
                                action = action_name,
                                effects_ms = effects_value,
                                layout_ms = layout_ms,
                                total_ms = total_ms,
                            ),
                        )
                        auto_completed[] += 1
                        auto_action_inflight[] = false
                        if BENCH_LIVE_AUTO &&
                           auto_completed[] >= length(auto_actions) &&
                           !auto_report_written[]
                            mkpath(dirname(auto_report_path))
                            write_livebench_csv(auto_report_path, auto_rows)
                            auto_report_written[] = true
                            total_vals = [r.total_ms for r in auto_rows]
                            median_total = isempty(total_vals) ? NaN : median(total_vals)
                            println(
                                "auto-livebench summary: actions=",
                                length(auto_rows),
                                " median_total_ms=",
                                round(median_total; digits = 2),
                            )
                            println("auto-livebench report: ", auto_report_path)
                        end
                    end
                    pending_start_ns[] = 0
                end
            end
            return
        end

        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(plot_layout; figure = (size = size,))
        fig_view = fit_window ? WGLMakie.WithConfig(fig; resize_to = :parent) : fig
        fig_ref[] = fig

        on(reset_button.value) do _
            reset_all_axes!()
        end

        header_dom = Grid(
            formula_DOM,
            reset_button;
            rows = "1fr",
            columns = "1fr auto",
            gap = "8px",
            align_items = "center",
        )
        cards = Grid(
            Card(header_dom, style = Styles("grid-area" => "header")),
            Card(mapping_dom, style = Styles("grid-area" => "sidebar")),
            Card(topo_widget, style = Styles("grid-area" => "topo")),
            Card(
                fig_view,
                style = Styles(
                    "grid-area" => "content",
                    "min-width" => "0",
                    "min-height" => "0",
                    "overflow" => "hidden",
                ),
            );
            columns = "5fr 1fr",
            rows = "1fr 6fr 4fr",
            areas = """
                'header header'
                'content sidebar'
                'content topo'
            """,
        )
        container_style =
            fit_window ?
            Styles(
                "height" => "calc(100vh - 24px)",
                "width" => "calc(100vw - 24px)",
                "margin" => "12px",
                "position" => :relative,
            ) :
            Styles(
                "height" => "$(1.2*size[2])px",
                "width" => "$(size[1])px",
                "margin" => "20px",
                "position" => :relative,
            )
        return DOM.div(
            css,
            Bonito.TailwindCSS,
            cards;
            style = container_style,
        )
    end
end

if BENCH_MODE
    run_action_bench(
        model;
        repeats = BENCH_REPEATS,
        warmup = BENCH_WARMUP,
        channel = BENCH_CHANNEL,
        out_csv = BENCH_OUT,
    )
else
    # --- build the full explorer (ERPExplorer already returns a Bonito.App) ---
    WGLMakie.activate!()
    explorer_app =
        BENCH_LIVE ?
        build_live_bench_app(model; positions = positions_sets) :
        ERPExplorer.explore(model; positions = positions_sets)
    if BENCH_LIVE
        println("Live bench enabled. Interact with the UI; each update prints `livebench #... total_ms=...`")
    end
    if BENCH_LIVE_AUTO
        println(
            "Auto live bench enabled. Starts after $(BENCH_LIVE_START_DELAY)s; action delay $(BENCH_LIVE_DELAY)s (minimum 5s).",
        )
        println("Auto actions file: ", BENCH_LIVE_ACTIONS_FILE)
        println("All supported actions listed in: ", ALL_LIVE_ACTIONS_FILE)
        if !isempty(BENCH_LIVE_REPORT)
            println("Requested auto report path: ", BENCH_LIVE_REPORT)
        end
    end
    server = start_server(explorer_app)
    println("Press Ctrl+C to stop.")
    wait(Condition())
end
