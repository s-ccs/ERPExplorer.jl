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

        # Extract variable names and types from the model.
        var_types = map(x -> x[2][3], variables)
        var_names = first.(variables)

        # Create dropdown menues on the left panel of the dashboard.
        mapping, mapping_dom = mapping_dropdowns(var_names, var_types)

        # Create interactive topoplot widget on the lower left panel of the dashboard.
        channel_chosen = Observable(4)
        if isnothing(positions)   
            topo_widget = nothing
        else
            topo_widget = topoplot_widget(positions, channel_chosen; size = size .* 0.5)
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
        Makie.onany_latest(ERP_data, mapping; update = true) do ERP_data, mapping # `update = true` means that it will run once immediately
            lock(lk) do
                _tmp = update_grid(
                    ERP_data,
                    formula_values,
                    var_names[var_types.==:CategoricalTerm],
                    var_names[var_types.==:ContinuousTerm],
                    mapping,
                )
                plot_layout[] = _tmp
            end
            return
        end

        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(plot_layout; figure = (size = size,))

        # Create header, sidebar, topo and content (figure) panels
        cards = Grid(
            Card(formula_DOM, style = Styles("grid-area" => "header")),
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
