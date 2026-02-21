"""
    explore(model::UnfoldModel; positions = nothing, size = (700, 600))
Run the dashboard for explorative ERP analysis.

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - Unfold linear model with categorical and continuous terms.\\
- `positions::Vector{Point{2, Float32}}` - x an y coordinates of the channels on topoplot.\\
- `size::Tuple{Float64, Float64}` - size of the topoplot panel.\\

**Return Value:** `Hyperscript.Node{Hyperscript.HTMLSVG}` - final HTML code of the dashboard.
"""
function explore(model::UnfoldModel; positions = nothing, size = (700, 600))
    Bonito.set_cleanup_time!(1) # wait one hour before closing session
    # Initialize the App from Bonito. App allows to wrap all interactive elements and to deploy them
    myapp = App() do
        # Extract formula terms and their features from the model.
        variables = extract_variables(model)
        # Create formula widgets for each term.
        formula_defaults, formula_toggle, formula_DOM, formula_values =
            formular_widgets(variables)
        reset_button = Bonito.Button(
            "Reset view";
            style = Styles(
                "padding" => "4px 8px",
                "min-height" => "24px",
            ),
        )

        # Extract variable names and types from the model.
        var_types = map(x -> x[2][3], variables)
        var_names = first.(variables)

        # Create dropdown menues on the left panel of the dashboard.
        mapping, mapping_dom = mapping_dropdowns(var_names, var_types)

        # Create interactive topoplot widget on the lower left panel of the dashboard.
        channel_chosen = Observable(1)
        topo_widget = nothing
        topo_size = size .* 0.5
        if positions isa AbstractDict || positions isa NamedTuple
            pos_sets = Dict{String,Any}()
            for (k, v) in pairs(positions)
                pos_sets[string(k)] = v
            end
            pos_keys = collect(keys(pos_sets))
            topo_select = Dropdown(pos_keys; index = 1)
            topo_widget_obs =
                Observable{Any}(topoplot_widget(pos_sets[pos_keys[1]], channel_chosen; size = topo_size))
            on(topo_select.value) do key
                channel_chosen[] = 1
                topo_widget_obs[] =
                    topoplot_widget(pos_sets[key], channel_chosen; size = topo_size)
            end
            topo_widget = Col(
                Row(DOM.div("Topoplot:"), topo_select, align_items = "center"),
                topo_widget_obs,
            )
        elseif isnothing(positions)
            topo_widget = nothing
        else
            topo_widget = topoplot_widget(positions, channel_chosen; size = topo_size)
        end
        # Create Observable DataFrame with predicted values (yhats) of the model.
        ERP_data = get_ERP_data(model, formula_toggle, channel_chosen)

        # when m changes update formula_defaults
        on(mapping) do m
            ft = formula_toggle.val
            ks_m = values(m)
            ks_ft = [t.first for t in ft]
            for k in ks_ft
                formula_defaults[k][] = k ∈ ks_m
            end
        end

        # Create a new empty grid layout

        plot_layout = Observable(S.GridLayout())

        # Create a new reentrant mutex (mutual exclusion) lock for safe thread synchronization during plot updates
        # mutex - allows only one thread to access protected code at a time
        # reentrant - allows the same thread to acquire the lock multiple times without causing a deadlock
        # When multiple events occur nearly simultaneously, the lock ensures that:
        # Only one plot update happens at a time and Plot data calculations complete fully before starting new ones
        lk = Base.ReentrantLock()

        # Update the the grid layout
        render_count = Ref(0)
        Makie.onany_latest(ERP_data, mapping; update = true) do ERP_data, mapping # `update = true` means that it will run once immediately
            lock(lk) do
                t0 = time_ns()
                _tmp = update_grid(
                    ERP_data,
                    formula_values,
                    var_names[var_types.==:CategoricalTerm],
                    var_names[var_types.==:ContinuousTerm],
                    mapping,
                )
                plot_layout[] = _tmp
                render_count[] += 1
                elapsed_ms = (time_ns() - t0) / 1e6
                println("render #", render_count[], " update_grid -> layout in ", round(elapsed_ms; digits = 2), " ms")
            end
            return
        end

        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(plot_layout; figure = (size = size,))

        on(reset_button.value) do _
            function collect_axes!(acc, item)
                if item isa Makie.Axis
                    push!(acc, item)
                elseif item isa Makie.GridLayoutBase.GridLayout
                    for child in Makie.GridLayoutBase.contents(item)
                        collect_axes!(acc, child)
                    end
                elseif item isa Makie.Figure
                    for child in item.content
                        collect_axes!(acc, child)
                    end
                end
            end

            axes = Makie.Axis[]
            collect_axes!(axes, fig.figure)
            for ax in axes
                Makie.reset_limits!(ax)
                Makie.autolimits!(ax)
            end
        end
        

        # Create header, sidebar, topo and content (figure) panels
        header_dom = Row(
            formula_DOM,
            reset_button;
            align_items = "center",
            justify_content = "space-between",
        )
        cards = Grid(
            Card(header_dom, style = Styles("grid-area" => "header")),
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
        )
        # Translate the cards and css into HTML code using DOMs 
        res = DOM.div(
            css,
            Bonito.TailwindCSS,
            cards;
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
