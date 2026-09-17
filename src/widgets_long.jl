"""
    mapping_dropdowns(varnames, var_types)
Map and arrange drop-down menus on the dashboard side panel.\\

Arguments:\\
- `varnames::Vector{Symbol}` - vector of the model formula terms.\\
- `var_types::Vector{Symbol}` - vector of types of the model formula terms.\\

Actions:\\
- Take categorical variables and put their values into drop-down menus.\\
- There will be 5 menus for: color, markers, line styles, column and row facets.\\
- There will be 2 checkboxes for drawing line and marker layers.\\
- Map each menu object to its name in the image.\\
- Create HTML containers using Bonito's Document Object Model (DOM).\\
- Arrange the containers on the panel using Col() and Row(). Specify their styling.\\

**Return Values:**\\
- `mapping::Observable{Dict{Symbol, Any}}` - interactive dictionary with menues and their default value.\\
- `mapping_dom::Hyperscript.Node{Hyperscript.HTMLSVG}` - dropdown menus in HTML code with styling and layout.\\
"""
function mapping_dropdowns(varnames, var_types; return_controls = false)
    cats = [v for (ix, v) in enumerate(varnames) if var_types[ix] == :CategoricalTerm]
    push!(cats, :none)

    c_dropdown = Dropdown(cats; index = length(cats)) #index is the default value
    m_dropdown = Dropdown(cats; index = length(cats))
    l_dropdown = Dropdown(cats; index = length(cats))
    col_dropdown = Dropdown(cats; index = length(cats))
    row_dropdown = Dropdown(cats; index = length(cats))
    line_checkbox = Bonito.Checkbox(true)
    marker_checkbox = Bonito.Checkbox(true)

    on(line_checkbox.value) do show_lines
        if !show_lines && !marker_checkbox.value[]
            marker_checkbox.value[] = true
        end
    end
    on(marker_checkbox.value) do show_markers
        if !show_markers && !line_checkbox.value[]
            line_checkbox.value[] = true
        end
    end

    mapping = @lift Dict(
        :color => $(c_dropdown.value),
        :marker => $(m_dropdown.value),
        :linestyle => $(l_dropdown.value),
        :col => $(col_dropdown.value),
        :row => $(row_dropdown.value),
        :show_lines => $(line_checkbox.value),
        :show_markers => $(marker_checkbox.value),
    )
    mapping_dom = Col(
        Row(DOM.div("lines:"), DOM.div(line_checkbox; var"data-testid" = "mapping-lines"), align_items = "center", justify_items = "end"),
        Row(
            DOM.div("markers:"),
            DOM.div(marker_checkbox; var"data-testid" = "mapping-markers"),
            align_items = "center",
            justify_items = "end",
        ),
        Row(DOM.div("color:"), DOM.div(c_dropdown; var"data-testid" = "mapping-color"), align_items = "center", justify_items = "end"),
        Row(DOM.div("marker:"), DOM.div(m_dropdown; var"data-testid" = "mapping-marker"), align_items = "center", justify_items = "end"),
        Row(
            DOM.div("linestyle:"),
            DOM.div(l_dropdown; var"data-testid" = "mapping-linestyle"),
            align_items = "center",
            justify_items = "end",
        ),
        Row(
            DOM.div("column facet"),
            DOM.div(col_dropdown; var"data-testid" = "mapping-col"),
            align_items = "center",
            justify_items = "end",
        ),
        Row(
            DOM.div("row facet"),
            DOM.div(row_dropdown; var"data-testid" = "mapping-row"),
            align_items = "center",
            justify_items = "end",
        ),
    )
    controls = Dict(:color => c_dropdown, :marker => m_dropdown, :linestyle => l_dropdown,
        :col => col_dropdown, :row => row_dropdown, :show_lines => line_checkbox, :show_markers => marker_checkbox)
    return return_controls ? (mapping, mapping_dom, controls) : (mapping, mapping_dom)

end

function topoplot_message(message)
    return DOM.div(
        message;
        class = "erp-status",
    )
end

topoplot_series_available(summary) = !isnothing(summary) && summary.status == :ok

function dashboard_panel_visibility(erp_collapsed, series_collapsed, topoplot_available)
    topoplot_available || return (show_erp = true, show_series = false)

    show_erp = !erp_collapsed
    show_series = !series_collapsed
    if !show_erp && !show_series
        return (show_erp = true, show_series = false)
    end
    return (show_erp = show_erp, show_series = show_series)
end

function topoplot_option(options, key::Symbol, default)
    for (k, v) in pairs(options)
        Symbol(k) == key && return v
    end
    return default
end

function validate_series_options(options)
    normalized = (; (Symbol(k) => v for (k, v) in pairs(options))...)
    width = get(normalized, :bin_width, nothing)
    count = get(normalized, :bin_num, nothing)
    !isnothing(width) && !isnothing(count) && throw(ArgumentError("Specify either bin_width or bin_num, not both."))
    if !isnothing(width)
        width isa Real && isfinite(width) && width > 0 || throw(ArgumentError("bin_width must be finite and positive."))
        return merge(normalized, (; bin_num = nothing))
    end
    count = isnothing(count) ? 5 : count
    count isa Real && isfinite(count) && isinteger(count) && 1 <= count <= 24 ||
        throw(ArgumentError("bin_num must be an integer between 1 and 24."))
    return merge(normalized, (; bin_num = Int(count)))
end

function topoplot_series_count_options(base_options, bin_num_value)
    base = (; (Symbol(k) => v for (k, v) in pairs(base_options) if !(Symbol(k) in (:bin_num, :bin_width)))...)
    return validate_series_options(merge(base, (; bin_num = bin_num_value)))
end

function topoplot_series_controls(options = (; bin_num = 5))
    normalized = validate_series_options(options)
    series_options = Observable{Any}(normalized; ignore_equal_values = true)
    if !isnothing(get(normalized, :bin_width, nothing))
        controls_dom = Row(DOM.div("Time-window width: $(normalized.bin_width) s"); gap = "8px")
        return series_options, controls_dom
    end
    bin_num_select = Dropdown(collect(1:24); index = normalized.bin_num)
    on(bin_num_select.value) do count
        series_options[] = topoplot_series_count_options(normalized, count)
    end
    on(series_options) do current
        count = get(current, :bin_num, nothing)
        if !isnothing(count) && count != bin_num_select.option_index[]
            bin_num_select.option_index[] = count
        end
    end
    controls_dom = Row(DOM.div("Topoplots:"), DOM.div("number"),
        DOM.div(bin_num_select; var"data-testid" = "bin-count"); align_items = "center", gap = "8px")
    return series_options, controls_dom
end

function topoplot_series_plot_count(summary, options)
    normalized = validate_series_options(options)
    count = normalized.bin_num
    if isnothing(count)
        lo, hi = extrema(summary.data.time)
        # A conservative upper bound, including a possible final partial bin.
        count = max(1, ceil(Int, (hi - lo) / normalized.bin_width))
    end
    return max(1, length(summary.groups)) * count
end

function topoplot_series_widget(summary, positions; size = (700, 220),
    options = (; bin_num = 5), max_plots = 60)
    summary.status == :ok || return topoplot_message(summary.message)
    count = topoplot_series_plot_count(summary, options)
    count <= max_plots || return topoplot_message(
        "This selection needs $(count) topoplots (limit $(max_plots)). Reduce the number of time windows or selected conditions.")
    width = max(200, Int(round(size[1])))
    group_count = max(1, length(summary.groups))
    height = max(220, Int(round(size[2])), 160 * group_count)
    fig = Figure(size = (width, height))
    defaults = (; axis = (; xlabel = "Time windows (s)", title = ""),
        visual = (; label_scatter = false, enlarge = 1.08, interp_resolution = (128, 128)))
    normalized = validate_series_options(options)
    visual = merge(defaults.visual, get(normalized, :visual, (;)))
    kwargs = merge(defaults, normalized, (; visual))
    plot_topoplotseries!(fig[1, 1], summary.data;
        positions, mapping = summary.mapping, kwargs...)
    return WGLMakie.WithConfig(fig; resize_to = (:parent, nothing))
end

function set_mapping_control!(controls, slot, value)
    control = controls[slot]
    if control isa Bonito.Checkbox
        value isa Bool || throw(ArgumentError("$(slot) expects a Bool."))
        control.value[] = value
    else
        index = findfirst(isequal(value), control.options[])
        isnothing(index) && throw(ArgumentError("Unknown value $(value) for $(slot)."))
        control.option_index[] = index
    end
    return nothing
end


"""
    topoplot_widget(positions; size = ())
Controls the topoplot in the lower left panel of the figure.\\
Highlight the location of the current electrode and allows electrode selection.\\

Arguments:\\
- `positions::Vector{Point{2, Float32}}` - x an y coordinates of the channels.\\
- `size::Tuple{Float64, Float64}` - size of the topoplot panel.\\

Actions:\\
- Create interactive scatter.
- Highlight the selected electrode with white color, others are grayed out.\\
- Create a topolot with a null interpolator and define its style and behavior.\\
- Hide decorations and spines.\\

**Return Values:**\\
- `topo_widget::Makie.FigureAxisPlot` - topoplot widget.\\
- `channel_chosen::Observable{Int64}` - number of the selected channel.\\
"""
function topoplot_widget(positions, channel_chosen; size = ())
    colorrange = vcat(0, 1)
    colormap = vcat(Gray(0.5), Gray(1))

    n_positions = length(to_value(positions))
    n_positions > 0 || throw(ArgumentError("positions must contain at least one channel"))

    marker_list = Observable(zeros(n_positions))
    marker_list.val[channel_chosen[]] = 1
    on(channel_chosen) do channel
        fill!(marker_list[], 0)
        marker_list[][channel] = 1
        notify(marker_list)
    end

    topo_widget = eeg_topoplot(
        marker_list;
        positions = positions,
        colorrange = colorrange,
        colormap = colormap,
        interpolation = TopoPlots.NullInterpolator(),
        figure = (; size = size),
        axis = (; xzoomlock = true, yzoomlock = true, xrectzoom = false, yrectzoom = false),
        label_scatter = (; strokecolor = :black, strokewidth = 1.0, markersize = 20.0),
    )

    on(events(topo_widget).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            plt, p = pick(topo_widget)
            if isa(plt, Makie.Scatter) && 1 <= p <= n_positions
                marker_list[] .= 0
                marker_list[][p] = 1
                notify(marker_list)
                channel_chosen[] = p
            end
        end
    end
    hidedecorations!(topo_widget.axis)
    hidespines!(topo_widget.axis)
    return topo_widget

end
