"""
    explore(model::UnfoldModel; positions = nothing, size = (700, 600), axis_options = nothing, auto_reset_view = true, fit_window = true)
Run the dashboard for explorative ERP analysis.

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - Unfold linear model with categorical and continuous terms.\\
- `positions::Vector{Point{2, Float32}}` - x an y coordinates of the channels on topoplot.\\
- `size::Tuple{Float64, Float64}` - size of the topoplot panel.\\
- `axis_options` - optional axis configuration passed to `update_grid` (e.g. `:x_unit`, labels, limits, ticks).\\
- `auto_reset_view::Bool` - if `true`, recenter axes after each data/mapping update (default `true`).\\
- `fit_window::Bool` - if `true`, fit dashboard width/height to browser viewport (default `true`).\\

**Return Value:** `Hyperscript.Node{Hyperscript.HTMLSVG}` - final HTML code of the dashboard.
"""
function explore(
    model::UnfoldModel;
    positions = nothing,
    size = (700, 600),
    axis_options = nothing,
    auto_reset_view = true,
    fit_window = true,
)
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
                "padding" => "4px 6px",
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
            selected_terms = Set(v for v in values(m) if v != :none)
            for (term, toggle_obs) in formula_defaults
                if term in selected_terms && !toggle_obs[]
                    # Mapping a variable should auto-enable it, but never disable other active terms.
                    toggle_obs[] = true
                end
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
        fig_ref = Ref{Union{Nothing,Makie.FigureAxisPlot}}(nothing)

        function reset_all_axes!()
            fig_obj = fig_ref[]
            isnothing(fig_obj) && return
            lock(lk) do
                function collect_axes!(acc, item)
                    if item isa Makie.Axis
                        push!(acc, item)
                    elseif item isa Makie.GridLayoutBase.GridLayout
                        for child in Makie.GridLayoutBase.contents(item)
                            collect_axes!(acc, child)
                        end
                    end
                end
                axes = Makie.Axis[]
                collect_axes!(axes, fig_obj.figure.layout)
                for ax in axes
                    Makie.reset_limits!(ax)
                    Makie.autolimits!(ax)
                end
            end
        end

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
                    axis_options = axis_options,
                )
                try
                    plot_layout[] = _tmp
                catch err
                    err_msg = sprint(showerror, err)
                    if occursin("Screen Session uninitialized", err_msg) ||
                       occursin("Session status: SOFT_CLOSED", err_msg)
                        return
                    end
                    rethrow(err)
                end
                render_count[] += 1
                elapsed_ms = (time_ns() - t0) / 1e6
                println("render #", render_count[], " update_grid -> layout in ", round(elapsed_ms; digits = 2), " ms")
                if auto_reset_view
                    reset_all_axes!()
                end
            end
            return
        end

        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(plot_layout; figure = (size = size,))
        fig_view = fit_window ? WGLMakie.WithConfig(fig; resize_to = :parent) : fig
        fig_ref[] = fig

        on(reset_button.value) do _
            reset_all_axes!()
        end
        

        # Create header, sidebar, topo and content (figure) panels
        header_dom = Grid(
            formula_DOM,
            reset_button;
            rows = "1fr",
            columns = "1fr auto",
            gap = "8px",
            align_items = "center",
        )
        cards = Grid(
            Card(header_dom, style = Styles("grid-area" => "header")),
            Card(mapping_dom, style = Styles("grid-area" => "sidebar")),
            Card(topo_widget, style = Styles("grid-area" => "topo")),
            Card(
                fig_view,
                style = Styles(
                    "grid-area" => "content",
                    "min-width" => "0",
                    "min-height" => "0",
                    "overflow" => "hidden",
                ),
            );
            columns = "5fr 1fr",
            rows = "1fr 6fr 4fr",
            areas = """
                'header header'
                'content sidebar'
                'content topo'
            """,
        )
        container_style =
            fit_window ?
            Styles(
                "height" => "calc(100vh - 24px)",
                "width" => "calc(100vw - 24px)",
                "margin" => "12px",
                "position" => :relative,
            ) :
            Styles(
                "height" => "$(1.2*size[2])px",
                "width" => "$(size[1])px",
                "margin" => "20px",
                "position" => :relative,
            )
        # Translate the cards and css into HTML code using DOMs 
        res = DOM.div(
            css,
            Bonito.TailwindCSS,
            cards;
            style = container_style,
        )
        return res
    end
end
