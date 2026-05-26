# Test Harness Overview

The `test/` folder contains both package tests and the dashboard benchmark harness.

## Entry points

- `runtests.jl`: `Pkg.test()` entrypoint.
- `dashboard_options.jl`: CLI benchmark/dashboard runner.
- `basic.jl`: smoke tests for `ERPExplorer.explore(...)`.

## Harness modes

- `serve`: starts the interactive dashboard server for manual inspection.
- `bench`: runs the built-in offline action scenario without a browser and writes median timings to CSV.
- `bench-live-auto`: starts the dashboard, replays a scenario file, and writes per-action live render timings to CSV.

## Internal structure (`test/lib`)

- `DashboardBenchHarness.jl`: module entrypoint/exports.
- `config.jl`: typed runtime config and mode constants.
- `cli.jl`: strict CLI parsing/validation and help text.
- `actions/`: registry, scenario IO, bench state, and live bindings.
- `io.jl`: report path helpers and CSV writers.
- `bench_runner.jl`: offline benchmark execution.
- `live/`: app builder, auto-playback timing/reporting, and server helper.
- `fixture.jl`: shared synthetic data/model fixture builder.

## Common commands

From package root:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

```bash
julia --project=. test/dashboard_options.jl --help
julia --project=. test/dashboard_options.jl --mode=serve
julia --project=. test/dashboard_options.jl --bench
julia --project=. test/dashboard_options.jl --mode=bench-live-auto \
  --bench-live-actions=test/livebench_actions_default.txt
```

## Action scenarios

- `livebench_actions_default.txt`: default scenario for `bench-live-auto`.

Action IDs are defined in code (`test/lib/actions/registry.jl`).
Scenario files are validated against that registry.

Scenario file format:
- one action ID per line,
- blank lines are ignored,
- lines beginning with `#` are comments,
- inline comments after `#` are ignored.

## Reports

- Offline bench reports default to `test/reports/bench_report_<timestamp>.csv`.
- Live-auto reports default to `test/reports/<scenario>_report_<timestamp>.csv`.
- Custom output paths can be provided via `--bench-out` and `--bench-live-report`.
- Live-auto playback starts after the first successful browser-backed render and
  then waits `--bench-live-start-delay` seconds. Per-action timeout defaults to
  60 seconds and can be changed with `--bench-live-timeout`.
- `test/reports/` is generated output and is ignored by Git.

Offline report columns:

```text
action_id,success,runs_completed,runs_requested,effects_median_ms,update_grid_median_ms,total_median_ms,error_message
```

Live-auto report columns:

```text
sequence,event_source,action_id,effects_ms,plot_layout_ms,total_ms
```
