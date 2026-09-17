# ERPExplorer.jl

Interactive exploration of fitted Unfold EEG/ERP models using WGLMakie and Bonito.
Requires Julia 1.11 or later and a browser with WebGL support.

[Documentation](https://s-ccs.github.io/ERPExplorer.jl/dev) · [Release notes](CHANGELOG.md)

## Open a fitted model

```julia
using ERPExplorer

loaded = ERPExplorer.load_unfold_jld2("model.jld2")
foreach(println, loaded.warnings)
app = ERPExplorer.explore(loaded.model; positions = loaded.positions)
display(app) # works in Pluto and Julia's browser-backed display
```

The loader accepts files written by `Unfold.save` and JLD2 files containing fitted
`UnfoldModel` objects. It reconstructs omitted model matrices before computing effects.
Use `model_key` to choose a model explicitly when a file contains more than one.

Optional electrode labels can come from the file, a vector, or a CSV/TSV table:

```julia
loaded = ERPExplorer.load_unfold_jld2("model.jld2";
    model_key = "models.first",
    channel_labels_file = "channels.tsv")
ERPExplorer.explore(loaded.model; positions = loaded.positions,
    fit_window = false, size = (600, 400))
```

For an already fitted in-memory model, use `ERPExplorer.explore(model; positions)`.
A numeric channel selector remains available when electrode positions are unknown.

## Controls

- Enable predictors in the formula row; open a predictor to change its values.
- Choose the event and channel, map categorical predictors to color/marker/style/facets,
  and switch line and marker layers independently.
- Open **Topoplots** to compute a series of time windows. The series starts collapsed,
  supports discrete predictors, and renders at most 60 topoplots by default.
- Use **Reset view** to restore the configured axis limits.

See the [input and usage guide](docs/src/usage.md) for supported formats, channel
indexing, shared predictor requirements, time-bin options and Pluto behavior.

## Development and verification

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. test/dashboard_options.jl --mode=serve
julia --project=. test/dashboard_options.jl --bench --bench-repeats=1
```

Package tests include numerical, saved-model and production-dashboard regressions.
CI also runs the actual dashboard in Chromium. See [test/README.md](test/README.md)
for browser tests, benchmark scenarios and real-data launching.
