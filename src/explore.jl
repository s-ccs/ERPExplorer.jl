"""
    explore(model::UnfoldModel; positions = nothing, size = (700, 600), axis_options = nothing, auto_reset_view = true, fit_window = true, topoplot_series = true, topoplot_series_options = (; bin_num = 5))
Run the dashboard for explorative ERP analysis.

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - Unfold linear model with categorical and/or continuous terms.\\
- `positions::Vector{Point{2, Float32}}` - x an y coordinates of the channels on topoplot.\\
- `size::Tuple{Float64, Float64}` - preferred dashboard size.\\
- `auto_reset_view::Bool = true` - recenter axes after each data/mapping update.\\
- `fit_window::Bool = true` - fit dashboard width to its parent container.\\
- `topoplot_series::Bool = true` - enable topoplot time-window series (open it with the Topoplots button).\\
- `topoplot_series_options = (; bin_num = 5)` - keyword options forwarded to `plot_topoplotseries!`.\\
- `topoplot_series_max_plots::Int = 60` - maximum number of topoplots rendered at once.\\
- `axis_options = nothing` - optional axis configurations \\
    Passed to `update_grid` (e.g. `:x_unit`, labels, limits, ticks).\\

  Supported `axis_options` keys with default values:
- `:x_unit` = `:ms` - x-axis unit. Supported values: `:s`, `:ms`. Example: ticks like "0.4" vs "400".
- `:xlabel` = `nothing` - x-axis label, inferred from `:x_unit`.
- `:ylabel` = `"Amplitude (uV)"` - y-axis label.
- `:xlimits`, `:ylimits` = `nothing` - axis limits.
- `:xticks`, `:yticks` = `nothing` - axis tick positions.
- `:xtickformat`, `:ytickformat` = `nothing` - axis tick label formatters.
- `:xscale`, `:yscale` = `nothing` - axis scaling options.


**Return Value:** `Bonito.App` - interactive dashboard app.
"""
function explore(
    model::UnfoldModel;
    positions = nothing,
    size = (700, 600),
    axis_options = nothing,
    auto_reset_view = true,
    fit_window = true,
    topoplot_series = true,
    topoplot_series_options = (; bin_num = 5),
    topoplot_series_max_plots = 60,
)
    validate_channel_positions(positions, model_channel_count(model))
    extract_variables(model) # Reject incompatible event schemas before opening a browser.
    return App() do session
        build_dashboard(session, model;
            positions, size, axis_options, auto_reset_view, fit_window,
            topoplot_series, topoplot_series_options, topoplot_series_max_plots).dom
    end
end
