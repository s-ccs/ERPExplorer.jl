

"""
    mapping_dropdowns(varnames, var_types)
Map and arrange dropdown menus on the left panel of the dashboard.\\

Arguments:\\
- `varnames::Vector{Symbol}` - vector of the model formula terms.\\
- `var_types::Vector{Symbol}` - vector of types of the model formula terms.\\

Actions:\\
- Take categorical variables and put their values into dropdown menus.\\
- There will be 5 menus for: color, markers, line styles, column and row facets.\\
- Map each menu object with its name on the Figure.\\
- Create HTML containers using Document Object Model (DOM) from Bonito.\\
- Arrange containers on the panel using Col() and Row(). Specify their styling.\\

**Return Values:**\\
- `mapping::Observable{Dict{Symbol, Symbol}}` - interactive dictionary with menues and their default value.\\
- `mapping_dom::Hyperscript.Node{Hyperscript.HTMLSVG}` - dropdown menus in HTML code with styling and layout.\\
"""
function mapping_dropdowns(varnames, var_types)
    cats = [v for (ix, v) in enumerate(varnames) if var_types[ix] == :CategoricalTerm]
    push!(cats, :none)

    c_dropdown = Dropdown(cats; index = 1)
    m_dropdown = Dropdown(cats; index = length(cats) - 1)
    l_dropdown = Dropdown(cats; index = length(cats))
    col_dropdown = Dropdown(cats; index = length(cats))
    row_dropdown = Dropdown(cats; index = length(cats))

    mapping = @lift Dict(
        :color => $(c_dropdown.value),
        :marker => $(m_dropdown.value),
        :linestyle => $(l_dropdown.value),
        :col => $(col_dropdown.value),
        :row => $(row_dropdown.value),
    )
    mapping_dom = Col(
        Row(DOM.div("color:"), c_dropdown, align_items = "center", justify_items = "end"),
        Row(DOM.div("marker:"), m_dropdown, align_items = "center", justify_items = "end"),
        Row(
            DOM.div("linestyle:"), #bug
            l_dropdown,
            align_items = "center",
            justify_items = "end",
        ),
        Row(
            DOM.div("column facet"),
            col_dropdown,
            align_items = "center",
            justify_items = "end",
        ),
        Row(
            DOM.div("row facet"),
            row_dropdown,
            align_items = "center",
            justify_items = "end",
        ),
    )
    return mapping, mapping_dom

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
    strokecolor = Observable(repeat([:red], length(to_value(positions)))) # crashing
    #channel_chosen = Observable(1)
    colorrange = vcat(0, 1)
    colormap = vcat(Gray(0.5), Gray(1))

    marker_list = Observable(zeros(length(to_value(positions))))
    marker_list.val[1] = 1

    topo_widget = eeg_topoplot(
        marker_list,
        nothing;
        positions = positions,
        colorrange = colorrange,
        colormap = colormap,
        interpolation = UnfoldMakie.NullInterpolator(),
        figure = (; size = size),
        axis = (; xzoomlock = true, yzoomlock = true, xrectzoom = false, yrectzoom = false),
        label_scatter = (; strokecolor = :black, strokewidth = 1.0, markersize = 20.0),
    )

    on(events(topo_widget).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            plt, p = pick(topo_widget)
            if isa(plt, Makie.Scatter)
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
