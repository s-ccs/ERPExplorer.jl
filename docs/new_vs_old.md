# ERPExplorer Changes
## 1) Package-level changes

### Biggest architectural change

- The plotting backend was switched from a custom Makie `PlotSpec` pipeline to **AlgebraOfGraphics (AoG)**.
- Old version: manual style building in `src/functions_plotting.jl` + `src/functions_style_scatter_lines.jl`.
- New version: AoG-based `draw_to_spec` in `src/functions_plotting.jl`.

### Dependency/compat changes

- New version adds `AlgebraOfGraphics` as a direct dependency in `Project.toml`.
- Rendering stack was updated to newer versions (`Makie 0.24`, `WGLMakie 0.13`, `TopoPlots 0.3`).
- Old version targets earlier stack (`Makie 0.21/0.22`, `WGLMakie 0.10/0.11`, `TopoPlots 0.2`).

### New user-facing functionality in the package

- `explore(...)` gained new keyword options:
  - `axis_options = nothing`
  - `auto_reset_view = true`
  - `fit_window = true`
- `positions` now supports multiple topoplot position sets via `Dict`/`NamedTuple` (selection dropdown in UI).
- Reset view logic is explicit and reusable (button + auto reset after updates).
- Layout can now scale with viewport by default (`fit_window=true`).
- Categorical value controls (e.g., fruit/animal) are now selectable in the formula header dropdown content.

### Axis configuration in new backend

`update_grid(...; axis_options = ...)` accepts:

- `:x_unit` (default `:ms`, also accepts `:s`)
- `:xlabel` (default `nothing`, auto label from `x_unit`)
- `:ylabel` (default `"Amplitude (uV)"`)
- `:xlimits` (default `nothing`)
- `:ylimits` (default `nothing`)
- `:xticks` (default `nothing`)
- `:yticks` (default `nothing`)
- `:xtickformat` (default `nothing`)
- `:ytickformat` (default `nothing`)
- `:xscale` (default `nothing`)
- `:yscale` (default `nothing`)

If a non-supported key is passed, the new code raises an error with the allowed key list.

### Stability behavior currently enforced

- In the new AoG path, if the same term is used for `linestyle` and `row/col` facet, linestyle is intentionally disabled for that render.
- Reason: this combination was unstable in AoG for this app (missing facets/legend inconsistencies).
- Color/marker with same-term faceting is still allowed.

## 2) `test/serve_widgets.jl` comparison

Both new and old scripts support:

- Running app server mode.
- Batch benchmark mode (`bench`).
- Live timing mode (`bench-live`).
- Auto-live mode (`bench-live-auto`).
- CLI parsing via `--key=value` and flags.

The new script extends this with file-driven auto actions and report output.

### Core runtime defaults

- New script default URL: `http://127.0.0.1:8082`
- Old script default URL: `http://127.0.0.1:8081`
- Default mode: `serve`

### CLI options (new script, exact defaults)

- `--mode` default: `"serve"`
  - accepted values used in code: `serve`, `bench`, `bench-live`, `bench-live-auto`
- `--bench` flag: equivalent to `--mode=bench`
- `--bench-live` flag: equivalent to `--mode=bench-live`
- `--bench-live-auto` flag: equivalent to `--mode=bench-live-auto`
- `--bench-repeats=<Int>` default: `5`
- `--bench-warmup=<Int>` default: `1`
- `--bench-channel=<Int>` default: `1`
- `--bench-out=<Path>` default: `""` (no bench CSV written unless set)
- `--bench-live-start-delay=<Float64>` default: `20` (seconds)
- `--bench-live-delay=<Float64>` default input: `5`
  - effective default: `5.0` seconds
  - effective minimum: **clamped to at least `5.0`** even if smaller value is passed
- `--bench-live-actions=<Path>` default:
  - `test/livebench_actions_default.txt`
- `--bench-live-report=<Path>` default: `""`
  - when empty, report path is auto-generated in the same folder as action file:
  - `<actions_stem>_report_<yyyymmdd_HHMMSS>.csv`

### Action files in new script

- Default scenario file:
  - `test/livebench_actions_default.txt`
- Full list of currently supported actions:
  - `test/livebench_actions_all.txt`
- New script validates action names before running and fails fast for unknown actions.

### Auto-live report behavior (new script)

- In `bench-live-auto`, each rendered action can be logged with:
  - `effects_ms`
  - `layout_ms`
  - `total_ms`
- Report is written to CSV:
  - explicit path from `--bench-live-report`, or
  - auto path beside the action file (default behavior).

