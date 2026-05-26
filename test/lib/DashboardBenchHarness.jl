"""
    DashboardBenchHarness

Internal library for the dashboard test/benchmark harness.
It provides:
- strict CLI parsing into typed config,
- registry-driven bench/live actions,
- offline and live-auto benchmark runners,
- fixture and report IO helpers used by `test/dashboard_options.jl`.
"""
module DashboardBenchHarness

using Dates
using Printf
using Statistics
using Unfold
using UnfoldSim
using Makie
using WGLMakie
using Bonito
using TopoPlots
using ERPExplorer
using DataFrames
using GeometryBasics
using Random

include("config.jl")
include("cli.jl")
include("actions/bench_state.jl")
include("actions/live_bindings.jl")
include("actions/registry.jl")
include("actions/scenario_io.jl")
include("io.jl")
include("bench_runner.jl")
include("live/auto_playback.jl")
include("live/ui_components.jl")
include("live/app_builder.jl")
include("live/server.jl")
include("synthetic_data.jl")
include("fixture.jl")

export ParsedCliArgs,
       HarnessConfig,
       MODE_HELP,
       MODE_SERVE,
       MODE_BENCH,
       MODE_BENCH_LIVE_AUTO,
       DEFAULT_HOST,
       DEFAULT_PORT,
       DEFAULT_SFREQ,
       DEFAULT_BENCH_REPEATS,
       DEFAULT_BENCH_WARMUP,
       DEFAULT_BENCH_CHANNEL,
       DEFAULT_LIVE_START_DELAY_SEC,
       DEFAULT_LIVE_STEP_DELAY_SEC,
       DEFAULT_LIVE_RENDER_SETTLE_DELAY_SEC,
       DEFAULT_LIVE_ACTION_TIMEOUT_SEC,
       parse_cli_args,
       parse_harness_config,
       usage_text,
       action_registry,
       registered_action_ids,
       action_ids_for_scope,
       live_action_triggers_render,
       default_bench_scenario,
       ensure_registered_action_ids,
       read_action_scenario,
       load_validated_scenario,
       default_bench_report_path,
       default_live_report_path,
       write_bench_csv,
       write_live_csv,
       run_offline_benchmark,
       build_live_benchmark_app,
       start_harness_server,
       build_benchmark_fixture,
       ACTION_SCOPE_BENCH,
       ACTION_SCOPE_LIVE

end
