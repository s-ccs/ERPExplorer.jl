#!/usr/bin/env julia
"""
Dashboard benchmark/test harness entrypoint.

Supported modes:
- `serve`: start interactive dashboard server for manual inspection.
- `bench`: run offline benchmark actions and write CSV summary report.
- `bench-live-auto`: start dashboard and replay actions from a scenario file,
  recording per-action timing metrics to CSV.

Usage:
- `julia --project=. test/dashboard_options.jl [--mode=<mode>] [options]`
- `julia --project=. test/dashboard_options.jl --bench`
- `julia --project=. test/dashboard_options.jl --help`

Notes:
- Action IDs are defined in the code registry under `test/lib/actions/`.
- Report paths default to timestamped CSV files under `test/reports/` when not set.
"""

import Pkg

const SCRIPT_DIR = @__DIR__
const ERP_PATH = get(ENV, "ERPEXPLORER_PATH", dirname(@__DIR__))
const ENV_DIR = joinpath(SCRIPT_DIR, "harness")

Pkg.activate(ENV_DIR)
Pkg.develop(path = ERP_PATH)
Pkg.instantiate()

include(joinpath(SCRIPT_DIR, "lib", "DashboardBenchHarness.jl"))
using .DashboardBenchHarness
using ERPExplorer

const CONFIG = parse_harness_config(
    ARGS;
    script_dir = SCRIPT_DIR,
)

if CONFIG.mode == MODE_HELP
    println(usage_text("test/dashboard_options.jl"))
    exit(0)
end

model, positions_sets = if !isempty(CONFIG.data_file)
    load_real_data_fixture(CONFIG)
elseif !isempty(CONFIG.data_dir) && CONFIG.mode != MODE_BENCH
    nothing, nothing
else
    build_benchmark_fixture(CONFIG)
end

if CONFIG.mode == MODE_BENCH
    run_offline_benchmark(model, CONFIG)
else
    DashboardBenchHarness.WGLMakie.activate!()

    app = if isempty(CONFIG.data_file) && !isempty(CONFIG.data_dir)
        build_real_data_launcher_app(CONFIG)
    elseif CONFIG.mode == MODE_BENCH_LIVE_AUTO
        build_live_benchmark_app(model, CONFIG; positions = positions_sets)
    else
        ERPExplorer.explore(model; positions = positions_sets)
    end

    if CONFIG.mode == MODE_BENCH_LIVE_AUTO
        println(
            "Auto live bench enabled. Starts $(CONFIG.live_start_delay_sec)s after first render; " *
            "action delay $(CONFIG.live_step_delay_sec)s (minimum 5s); " *
            "action timeout $(CONFIG.live_action_timeout_sec)s.",
        )
        println("Auto actions file: ", CONFIG.live_actions_file)
        if !isempty(CONFIG.live_report_file)
            println("Requested auto report path: ", CONFIG.live_report_file)
        end
    end

    start_harness_server(app; host = CONFIG.host, port = CONFIG.port)
    println("Press Ctrl+C to stop.")
    wait(Condition())
end
