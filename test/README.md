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

## Production regressions and browser tests

`regressions.jl` fits small deterministic models and verifies save/load predictions,
channel mappings, shared event schemas, time-bin options, benchmark failure propagation
and the actual production dashboard. The live benchmark calls the same `build_dashboard`
implementation used by `explore`.

Run browser tests with Julia 1.11+ and Node 24:

```sh
julia --project=test/harness -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
cd test/browser
npm ci
npx playwright install chromium
npm test
```

The browser fixture tests real slider callbacks, event/channel selection, line/marker
modes, topoplot bins and visibility, reload, and an embedded 600×300 container.
It uses synthetic data; diagnostic outputs exist only in the test fixture.

For a separately running fixture, set `ERP_BROWSER_EXTERNAL=1` and optionally
`ERP_BROWSER_URL`. `ERP_BROWSER_SERVER_COMMAND` overrides the Julia server command.
Failure screenshots and traces are written under `test/browser/test-results/`.

## Real-data launcher

```sh
julia --project=. test/dashboard_options.jl --mode=serve --data-dir=/path/to/models
julia --project=. test/dashboard_options.jl --mode=serve --data-file=/path/to/model.jld2 --channel-labels-file=/path/to/channels.tsv
```

`--model-key` selects a nested model and `--montage` chooses the supported label lookup.
See `docs/src/usage.md` for exact input and indexing requirements. Loader warnings are
shown by the launcher as well as printed to the terminal.

With `--data-dir`, the dashboard shows the current dataset and a **Change dataset**
button. It returns to the selection screen with the previous file and loading options
filled in. Choose another source and press **Load** to start a fresh dashboard.
The file list is refreshed when you return; failed loads retain your entries for correction.

A failed offline benchmark writes its report and exits with an error. A successful CSV
write alone is not a successful benchmark. CI uploads the report for diagnosis.

The Pluto notebooks in `notebooks/` are maintained development reproductions. Verify
both notebooks in a real Pluto session before changing embedding or widget behavior.
