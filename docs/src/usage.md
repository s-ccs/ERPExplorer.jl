# Inputs, controls and embedding

## Supported inputs

`ERPExplorer.explore(model)` accepts a fitted `UnfoldModel`. Epoched and continuous-time
models are supported. Predictor controls cover categorical and continuous terms, spline
terms supported by Unfold, and predictors within interactions.

`ERPExplorer.load_unfold_jld2(path; ...)` accepts:

- Standard `.jld2` files produced by `Unfold.save`, including omitted design matrices.
- JLD2 objects saved directly under a key.
- Models within dictionaries, NamedTuples, tuples, or short nonnumeric vectors.

The result is `(; model, positions, warnings)`. Print or display `warnings` in your
application. Raw EEG files and models from other statistical packages are not input
formats for this loader.

### Selecting a model

An explicit `model_key` can be a JLD2 key/group path (`"group/model"`) or a discovered
container path (`"models.first"`, `"models[2]"`). The same discovered paths printed in
warnings can be passed back to the loader. Use distinct container keys so paths are
unambiguous. Without a key, the first discovered model is selected deterministically,
and the loader warns if other models are present.

```julia
using ERPExplorer
loaded = ERPExplorer.load_unfold_jld2("model.jld2"; model_key = "uf")
foreach(println, loaded.warnings)
display(ERPExplorer.explore(loaded.model; positions = loaded.positions))
```

### Switching datasets in the launcher

Start the selection screen with:

```sh
julia --project=. test/dashboard_options.jl --mode=serve --data-dir=/path/to/models
```

Choose a dataset and press **Load**. The dashboard header shows the loaded filename.
Use **Change dataset** to return to selection, choose another file and load it.
The previous file, model key, channel-label file and montage remain filled in.
Each load opens a fresh dashboard, resetting its plot controls. The file list refreshes
when you return, and a failed load keeps your entries so you can correct them.

### Channel labels and positions

Label precedence is: explicit `channel_labels`, `channel_labels_file`, then metadata
in the JLD2 file. Metadata names include `channel_labels`, `channel_names`, `ch_names`,
`labels`, `channels`, `chanlocs`, and `electrodes`.

Labels must cover every model channel in the model's order. Missing, blank or duplicate
labels and label-count mismatches raise an error. ERPExplorer never removes entries or
renumbers channels silently.

A CSV/TSV mapping needs a label/name column (for example `label`, `channel_name` or
`name`), or exactly one column. An optional index column (`index`, `channel_index`,
`channel_idx`, `idx`, `chan` or `channel_number`) must contain **each integer 1:N once**.
Rows may be unordered; gaps, duplicates, zero-based indices and non-integers are rejected.

```text
index	label
2	Fp2
1	Fp1
3	C3
4	C4
```

Use `channel_labels_file = "channels.tsv"` for this example. The supported montage
is `standard_1005` (10/05; aliases `standard_10_05`, `10_05`, `1005`). Unknown labels or
an unsupported montage produce a warning and `positions = nothing`. The numeric
channel selector still exposes all channels.

Explicit `positions` passed to `explore` must contain N finite 2D points in model order.
Named collections of alternative position sets are supported, but every set must cover
all N channels. Partial montages require an explicit model/channel subset first.

### Multiple events and shared predictors

The event selector filters the same effects cache used by the ERP and topoplot panels.
Changing the channel or event does not recalculate model effects.

A continuous predictor shared by several formulas gets controls spanning the minimum
and maximum across those formulas. This can include extrapolation outside one event's
observed range; choose values appropriate for the selected event.

A shared categorical predictor must have the same set of levels in every formula in
which it occurs. Shared predictors must also have compatible term types; shared spline
terms require equal bounds. Incompatible models are rejected with a clear message.
Explore separately fitted event models when their categorical levels or spline domains
differ. This avoids silently dropping levels or applying invalid levels to another formula.

## Topographic time series

The series is enabled by default and starts collapsed. Open **Topoplots** to compute
it. It requires channel positions and no enabled continuous predictors. Active discrete
conditions form rows; the requested time windows form columns.

```julia
ERPExplorer.explore(model; positions,
    topoplot_series_options = (; bin_num = 4))

ERPExplorer.explore(model; positions,
    topoplot_series_options = (; bin_width = 0.025)) # seconds
```

Use exactly one of `bin_num` (an integer 1–24) or a positive `bin_width`. Bin-width mode
preserves the requested width and displays it in the controls. Other UnfoldMakie options
are forwarded. Invalid options are rejected instead of silently clamped or discarded.

Rendering is limited to `topoplot_series_max_plots = 60` by default. If a selection
exceeds the limit, the panel explains how to reduce the conditions or time windows.
Raise the limit explicitly only after checking performance on your hardware. Hiding and
showing an unchanged series reuses it; ERP style changes do not rebuild the series.

## Pluto and small containers

`fit_window = true` fits the width of the parent container. `fit_window = false` uses
`size[1]` as the preferred width, capped by the available parent width. `size[2]` sets
the dashboard height. Charts resize to their panels in both modes. Narrow containers
stack the panels and allow vertical scrolling so controls and plots remain reachable.

All page colors and layout styles are scoped to ERPExplorer. The host notebook's body
styles are preserved. The [development notebooks](https://github.com/s-ccs/ERPExplorer.jl/tree/main/notebooks)
isolate slider and embedding behavior; they are development repros, not required at runtime.

## Axis options

`axis_options` accepts `x_unit` (`:ms` or `:s`), labels, tick positions/formatters, scales,
and `xlimits`/`ylimits`. Limits and ticks use the displayed units. For example:

```julia
ERPExplorer.explore(model;
    axis_options = Dict(:x_unit => :s, :xlimits => (-0.1, 0.5), :ylabel => "Amplitude (µV)"))
```

Auto reset and **Reset view** preserve explicitly configured limits.

Interactive topoplot series uses a 128×128 interpolation grid per map. To request
a finer grid, pass `topoplot_series_options = (; bin_num = 5, visual =
(; interp_resolution = (256, 256)))`. This changes drawing resolution, not the
predicted values or time-window averages.
