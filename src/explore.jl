"""
    explore(model::UnfoldModel; positions = nothing, size = (700, 600))
Run the dashboard for explorative ERP analysis.

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - Unfold linear model with categorical and continuous terms.\\
- `positions::Vector{Point{2, Float32}}` - x an y coordinates of the channels.\\
- `size::Tuple{Float64, Float64}` - size of the topoplot panel.\\

Actions:\\
- Extract formula terms and itheir features.\\
- Create interactive formula with checkboxes.\\
- Arrange and map dropdown menus.\\
- Create interactive topoplot.\\
- Create Observable DataFrame with predicted values (yhats) and more.\\
- Create `GridLayout`.\\
- Use `Base.ReentrantLock`, a synchronization primitive_ to manage concurrent access to shared resources in multi-threaded programs\\
- Create Figure.\\
- Translate into into HTML code using DOMs.

**Return Value:** `Hyperscript.Node{Hyperscript.HTMLSVG}` - final HTML code of the dashboard.
"""
function explore(model::UnfoldModel; positions = nothing, size = (700, 600))
    App() do
        variables = extract_variables(model)
        widget_checkbox, widget_signal, widget_dom, value_ranges =
            formular_widgets(variables)

        var_types = map(x -> x[2][3], variables)
        varnames = first.(variables)

        mapping, mapping_dom = mapping_dropdowns(varnames, var_types)

        if isnothing(positions)
            channel = Observable(1)
            topo_widget = nothing
        else
            topo_widget, channel = topoplot_widget(positions; size = size .* 0.5)
        end

        yhats_sig = yhats_signal(model, widget_signal, channel)
        on(mapping) do m
            ws = widget_signal.val
            ks_m = values(m)
            ks_ws = [w.first for w in ws]
            for k in ks_ws
                widget_checkbox[k][] = k ∈ ks_m
            end
        end

        obs = Observable(S.GridLayout())
        l = Base.ReentrantLock()

        Makie.onany_latest(yhats_sig, mapping; update = true) do eff, mapping # update = true means only, that it is run once immediately
            lock(l) do
                obs[] = plot_data(
                    eff,
                    value_ranges,
                    varnames[var_types.==:CategoricalTerm],
                    varnames[var_types.==:ContinuousTerm],
                    mapping,
                )
            end
            return
        end
        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(obs; figure = (size = size,))
        res = DOM.div(
            css,
            Bonito.TailwindCSS,
            Grid(
                Card(widget_dom, style = Styles("grid-area" => "header")),
                Card(mapping_dom, style = Styles("grid-area" => "sidebar")),
                Card(topo_widget, style = Styles("grid-area" => "topo")),
                Card(fig, style = Styles("grid-area" => "content"));
                columns = "5fr 1fr",
                rows = "1fr 6fr 4fr",
                areas = """
'header header'
'content sidebar'
'content topo'
""",
            );
            style = Styles(
                "height" => "$(1.2*size[2])px",
                "width" => "$(size[1])px",
                "margin" => "20px",
                "position" => :relative,
            ),
        )
        return res
    end
end
