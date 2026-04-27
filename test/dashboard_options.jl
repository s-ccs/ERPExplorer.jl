#!/usr/bin/env julia
"""
This script is used for testing and benchmarking the dashboard with various options.
Setting and running takes some time.

How to use: 
> julia test/dashboard_options.jl [--mode=<mode>] [options]
> julia --project=. test/dashboard_options.jl --bench

Modes:
  serve             Starts the dashboard server at http://127.0.0.1:8082. Default.
  bench             Run predefined dashboard actions without opening the browser and store the results of benchmark in CSV file.
  bench-live        Start the dashboard and print timing for manual interactions.???
  bench-live-auto   Start the dashboard and automatically run actions from a file.???

### Action files in new script

- Default scenario file:
  - `test/livebench_actions_default.txt`
- Full list of currently supported actions:
  - `test/livebench_actions_all.txt`

### Auto-live report behavior (new script)

- In `bench-live-auto`, each rendered action can be logged with:
  - `effects_ms`
  - `layout_ms`
  - `total_ms`
- Report is written to CSV:
  - explicit path from `--bench-live-report`, or
  - auto path beside the action file (default behavior).
"""

import Pkg
using Printf
using Dates

const ERP_PATH = get(ENV, "ERPEXPLORER_PATH", dirname(@__DIR__))
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
const DEFAULT_REPORTS_DIR = joinpath(@__DIR__, "reports")

# Use a persistent environment next to this script
const ENV_DIR = joinpath(@__DIR__, ".erp_env")
Pkg.activate(ENV_DIR)
#Pkg.develop(url="https://github.com/MakieOrg/AlgebraOfGraphics.jl")
Pkg.develop(path=ERP_PATH)

using Unfold, UnfoldSim
using Makie, WGLMakie
using Bonito
using TopoPlots
using ERPExplorer
using Statistics


# --- simulate + fit ---
dataS, evts, _positions = ERPExplorer.gen_data()
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

include(joinpath(@__DIR__, "dashboard_options_support.jl"))


if BENCH_MODE
    bench_out_path = isempty(BENCH_OUT) ? default_bench_report_path() : BENCH_OUT
    run_action_bench(
        model;
        repeats = BENCH_REPEATS,
        warmup = BENCH_WARMUP,
        channel = BENCH_CHANNEL,
        out_csv = bench_out_path,
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
