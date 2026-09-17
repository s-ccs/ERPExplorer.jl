# Session-scoped observable subscriptions shared by the production app and its tests.
function observe_latest(f, session, observables...; update = false)
    input = Observable{Any}(map(to_value, observables))
    onany(session, observables...) do args...
        input[] = args
    end
    return Makie.on_latest(args -> f(args...), session, input; update)
end

function build_dashboard(session,
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
    topoplot_series_max_plots isa Integer && topoplot_series_max_plots > 0 ||
        throw(ArgumentError("topoplot_series_max_plots must be a positive integer."))
    rendered = Observable{Any}(nothing)
    render_error = Observable{Any}(nothing)
    browser_ready = Observable(false)
    frontend_loaded = Observable(false)
    effects_ms = Ref(0.0)
    effects_count = Ref(0)
    series_builds = Ref(0)
    closed = Ref(false)
    on(session, session.on_close) do _
        closed[] = true
    end
    # Extract formula terms and their features from the model.
    variables = extract_variables(model)
    # Create formula widgets for each term.
    formula_defaults, formula_toggle, formula_DOM, formula_values =
        formular_widgets(variables)
    reset_button = Bonito.Button(
        "Reset view";
        style = Styles(
            "padding" => "2px 6px",
            "min-height" => "24px",
            "min-width" => "7.75rem",
            "width" => "100%",
            "font-size" => "0.875rem",
            "margin" => "0",
        ),
    )

    # Extract variable names and types from the model.
    var_types = map(x -> x[2][3], variables)
    var_names = first.(variables)

    # Create dropdown menues on the right panel of the dashboard.
    mapping, mapping_dom, mapping_controls = mapping_dropdowns(var_names, var_types; return_controls = true)

    # Create interactive channel topoplot widget on the lower right panel of the dashboard.
    channel_chosen = Observable(1; ignore_equal_values = true)
    channel_select = Dropdown(collect(1:model_channel_count(model)); index = 1)
    on(session, channel_select.value) do channel
        channel_chosen[] = channel
    end
    on(session, channel_chosen) do channel
        1 <= channel <= model_channel_count(model) || throw(ArgumentError("Channel is outside the model."))
        channel_select.option_index[] = channel
    end
    channel_dom = Row(DOM.div("channel:"), DOM.div(channel_select; var"data-testid" = "channel-select"); align_items = "center", gap = "8px")
    selected_positions = Observable{Any}(nothing; ignore_equal_values = true)
    channel_topo_widget = nothing
    channel_topoplot_available = true
    topo_extent = min(280, max(220, Int(round(min(size...) * 0.46))))
    topo_size = (topo_extent, topo_extent)
    if positions isa AbstractDict || positions isa NamedTuple
        pos_sets = Dict{String,Any}()
        for (k, v) in pairs(positions)
            pos_sets[string(k)] = v
        end
        pos_keys = sort!(collect(keys(pos_sets)))
        isempty(pos_keys) &&
            throw(ArgumentError("positions must contain at least one position set"))
        topo_select = Dropdown(pos_keys; index = 1)
        selected_positions[] = pos_sets[pos_keys[1]]
        topo_widget_obs = Observable{Any}(
            topoplot_widget(selected_positions[], channel_chosen; size = topo_size),
        )
        on(session, topo_select.value) do key
            channel_chosen[] = 1
            selected_positions[] = pos_sets[key]
            topo_widget_obs[] =
                topoplot_widget(selected_positions[], channel_chosen; size = topo_size)
        end
        channel_topo_widget = Col(
            Row(DOM.div("Topoplot:"), topo_select, align_items = "center"),
            topo_widget_obs,
        )
    elseif isnothing(positions)
        channel_topoplot_available = false
        channel_topo_widget = DOM.div()
    else
        selected_positions[] = positions
        channel_topo_widget = topoplot_widget(positions, channel_chosen; size = topo_size)
    end
    # Create Observable DataFrame with predicted values (yhats) of the model.
    ERP_effects = get_ERP_effects(model, formula_toggle; session, on_effects = elapsed -> begin
        effects_ms[] = elapsed
        effects_count[] += 1
    end)
    event_options = Observable{Vector{Any}}(Any[nothing]; ignore_equal_values = true)
    selected_event = Observable{Any}(nothing; ignore_equal_values = true)
    event_select = Dropdown(
        event_options;
        index = 1,
        option_to_string = event_selection_label,
    )
    on(session, event_select.value) do event
        selected_event[] = event
    end
    on(session, ERP_effects; update = true) do erp_state
        values = event_selection_values(erp_state)
        selected = selected_event[]
        target_index = event_selection_index(values, selected)
        if event_select.option_index[] > length(values)
            event_select.option_index[] = 1
        end
        event_options[] = values
        event_select.option_index[] = target_index
        selected_event[] = values[target_index]
    end
    event_dom = lift(event_options) do values
        length(values) > 1 ?
        Row(DOM.div("event:"), DOM.div(event_select; var"data-testid" = "event-select"), align_items = "center", gap = "8px") :
        DOM.div()
    end
    ERP_event_effects = get_event_ERP_effects(ERP_effects, selected_event; session)
    ERP_data = get_channel_ERP_data(ERP_event_effects, channel_chosen; session)
    categorical_terms = var_names[var_types .== :CategoricalTerm]
    continuous_terms = var_names[is_continuous_like.(var_types)]
    topo_widget = channel_topo_widget

    # when m changes update formula_defaults
    on(session, mapping) do m
        selected_terms = Set(mapped_categorical_terms(m))
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
            end
        end
    end

    # Update the the grid layout
    render_count = Ref(0)
    observe_latest(session, ERP_data, mapping; update = true) do erp_state, mapping # `update = true` means that it will run once immediately
        closed[] && return
        lock(lk) do
            t0 = time_ns()
            try
            _tmp = update_grid(
                erp_state,
                formula_values,
                categorical_terms,
                continuous_terms,
                mapping,
                axis_options = axis_options,
                plot_size = size,
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
            rendered[] = (; kind = :erp, effects_ms = effects_ms[], plot_layout_ms = elapsed_ms, count = render_count[])
            catch err
                render_error[] = err
                rethrow()
            end
        end
        return
    end

    css = Asset(joinpath(@__DIR__, "..", "style.css"))
    fig = plot(plot_layout; figure = (size = size,))
    fig_view = WGLMakie.WithConfig(fig; resize_to = :parent)
    fig_ref[] = fig

    on(session, reset_button.value) do _
        reset_all_axes!()
    end

    series_width = size[1]
    series_height = max(240, Int(round(size[2] * 0.5)))
    series_options, series_controls_dom = topoplot_series_controls(topoplot_series_options)
    topoplot_series_summary = Observable{Any}(nothing; ignore_equal_values = true)
    if topoplot_series
        observe_all(session,
            ERP_event_effects,
            selected_positions;
            update = true,
        ) do erp_state, current_positions
            topoplot_series_summary[] = prepare_topoplot_series_data(
                erp_state,
                current_positions,
                categorical_terms,
                continuous_terms,
            )
        end
    end
    topoplot_available = lift(topoplot_series_summary) do summary
        topoplot_series_available(summary)
    end
    erp_collapsed = Observable(false; ignore_equal_values = true)
    series_collapsed = Observable(true; ignore_equal_values = true)
    panel_visibility = lift(
        erp_collapsed,
        series_collapsed,
        topoplot_available,
    ) do erp_hidden, series_hidden, available
        dashboard_panel_visibility(erp_hidden, series_hidden, available)
    end

    collapse_button_style = Styles(
        "min-width" => "7.75rem",
        "width" => "100%",
        "font-size" => "0.875rem",
        "padding" => "2px 6px",
        "margin" => "0",
    )
    erp_toggle_button = Bonito.Button("ERP"; style = collapse_button_style)
    series_toggle_button = Bonito.Button("Topoplots"; style = collapse_button_style)
    on(session, erp_toggle_button.value) do _
        topoplot_available[] || return
        next_collapsed = !erp_collapsed[]
        erp_collapsed[] = next_collapsed
        if next_collapsed
            series_collapsed[] = false
        end
    end
    on(session, series_toggle_button.value) do _
        topoplot_available[] || return
        next_collapsed = !series_collapsed[]
        series_collapsed[] = next_collapsed
        if next_collapsed
            erp_collapsed[] = false
        end
    end
    on(session, topoplot_available) do available
        if !available
            erp_collapsed[] = false
        end
    end
    on(session, panel_visibility; update = true) do visible
        erp_toggle_button.content[] = "ERP"
        series_toggle_button.content[] = "Topoplots"
    end
    function panel_toggle_style(active, available)
        available || return "display: none;"
        opacity = active ? "1" : "0.45"
        filter = active ? "none" : "grayscale(1)"
        return join(
            [
                "display: block",
                "width: 100%",
                "opacity: $(opacity)",
                "filter: $(filter)",
            ],
            "; ",
        )
    end
    erp_toggle_style = lift(panel_visibility, topoplot_available) do visible, available
        panel_toggle_style(visible.show_erp, available)
    end
    series_toggle_style = lift(panel_visibility, topoplot_available) do visible, available
        panel_toggle_style(visible.show_series, available)
    end
    action_controls_dom = Col(
        reset_button,
        DOM.div(erp_toggle_button; style = erp_toggle_style),
        DOM.div(series_toggle_button; style = series_toggle_style);
        gap = "6px",
        align_items = "stretch",
    )
    topoplot_status_dom = lift(topoplot_series_summary, topoplot_available) do summary, available
        if available || isnothing(summary) || isempty(summary.message)
            return DOM.div()
        end
        return DOM.div(
            summary.message;
            class = "erp-status",
        )
    end
    topoplot_series_dom = Observable{Any}(DOM.div())
    series_key = Ref{Any}(nothing)
    if topoplot_series
        observe_latest(session, topoplot_series_summary, selected_positions, series_options, panel_visibility; update = true) do summary, current_positions, current_options, visible
            # WGLMakie waits for browser acknowledgements while inserting plots.
            # A concurrent first-time series build can block those replies during compilation.
            lock(lk) do
                closed[] && return
                visible.show_series && topoplot_series_available(summary) || return
                key = series_key[]
                if !isnothing(key) && key.summary === summary && key.positions === current_positions && isequal(key.options, current_options)
                    return
                end
                try
                    t0 = time_ns()
                    topoplot_series_dom[] = topoplot_series_widget(summary, current_positions;
                        size = (series_width, series_height), options = current_options,
                        max_plots = topoplot_series_max_plots)
                    series_key[] = (; summary, positions = current_positions, options = current_options)
                    series_builds[] += 1
                    rendered[] = (; kind = :series, effects_ms = 0.0, plot_layout_ms = (time_ns() - t0) / 1e6, count = series_builds[])
                catch err
                    render_error[] = err
                    rethrow()
                end
            end
        end
    end
    topoplot_series_panel = Grid(
        series_controls_dom,
        DOM.div(
            topoplot_series_dom;
            style = "width: 100%; height: 100%; min-height: 0; overflow-y: auto; overflow-x: hidden;",
        );
        rows = "auto minmax(0, 1fr)",
        columns = "1fr",
        gap = "6px",
    )

    # Create header, sidebar, topo and content (figure) panels
    sidebar_dom = Col(channel_dom, event_dom, mapping_dom; class = "erp-sidebar", gap = "10px", align_items = "stretch")
    header_dom = Grid(
        Col(
            formula_DOM,
            topoplot_status_dom;
            gap = "4px",
        ),
        action_controls_dom;
        rows = "1fr",
        columns = "1fr auto",
        gap = "8px",
        align_items = "center",
    )
    card_style = Styles(
        "box-sizing" => "border-box",
        "min-width" => "0",
        "min-height" => "0",
        "overflow" => "hidden",
    )
    header_card = DOM.div(
        Card(
            header_dom;
            width = "100%",
            height = "100%",
            style = Styles(
                card_style,
                "overflow" => "visible",
                "position" => "relative",
                "z-index" => 20,
            ),
        );
        style = "grid-area: header; min-width: 0; min-height: 0; overflow: visible; position: relative; z-index: 20;",
    )
    content_card = Card(
        fig_view,
        width = "100%",
        height = "100%",
        style = Styles(
            card_style,
            "min-width" => "0",
            "min-height" => "0",
            "overflow" => "hidden",
        ),
    )
    sidebar_card = Card(
        sidebar_dom;
        width = "100%",
        height = "100%",
        style = Styles(
            card_style,
            "overflow" => "visible",
            "position" => "relative",
            "z-index" => 15,
        ),
    )
    topo_card =
        channel_topoplot_available ?
        Card(topo_widget; width = "100%", height = "100%", style = card_style) :
        DOM.div()
    series_card = Card(
        topoplot_series_panel,
        width = "100%",
        height = "100%",
        style = Styles(
            card_style,
            "min-width" => "0",
            "min-height" => "0",
            "overflow" => "hidden",
        ),
    )
    function dashboard_grid_class(visible)
        mode = visible.show_erp && visible.show_series ? "both" : visible.show_erp ? "erp" : "series"
        topo = channel_topoplot_available ? "with-topo" : "without-topo"
        return "erp-dashboard-grid erp-view-$(mode) $(topo)"
    end
    function dashboard_panel_style(area, visible)
        if visible
            return "grid-area: $(area); min-width: 0; min-height: 0; overflow: hidden; display: block;"
        end
        return "grid-area: $(area); min-width: 0; min-height: 0; overflow: hidden; display: none;"
    end
    dashboard_class = lift(dashboard_grid_class, panel_visibility)
    content_style = lift(panel_visibility) do visible
        dashboard_panel_style("content", visible.show_erp)
    end
    sidebar_style = lift(panel_visibility) do visible
        if visible.show_erp || visible.show_series
            return "grid-area: sidebar; min-width: 0; min-height: 0; overflow: visible; display: block; position: relative; z-index: 15;"
        end
        return dashboard_panel_style("sidebar", false)
    end
    topo_style = lift(panel_visibility) do visible
        dashboard_panel_style("topo", visible.show_erp && channel_topoplot_available)
    end
    series_style = lift(panel_visibility) do visible
        dashboard_panel_style("series", visible.show_series)
    end
    cards = DOM.div(
        header_card,
        DOM.div(content_card; style = content_style, var"data-testid" = "erp-panel"),
        DOM.div(sidebar_card; style = sidebar_style, var"data-testid" = "sidebar"),
        DOM.div(topo_card; style = topo_style, var"data-testid" = "channel-topoplot"),
        DOM.div(series_card; style = series_style, var"data-testid" = "series-panel");
        class = dashboard_class,
    )
    container_style = Styles(
        "width" => (fit_window ? "100%" : "$(size[1])px"),
        "max-width" => "100%",
        "height" => "$(size[2])px",
        "min-width" => "0",
        "position" => "relative",
    )
    # Translate the cards and css into HTML code using DOMs.
    res = DOM.div(
        css,
        cards;
        style = container_style,
        class = "erp-explorer",
        var"data-testid" = "erp-explorer",
    )
    # A canvas can be visible before WGLMakie has completed its browser handshake.
    # Wait asynchronously so incoming initialization messages can still be handled.
    on(session, frontend_loaded) do loaded
        loaded || return
        @async begin
            status = timedwait(() -> closed[] || any(
                screen -> screen isa WGLMakie.Screen && WGLMakie.scene_already_displayed(screen),
                Makie.get_scene(fig).current_screens), 180; pollint = 0.05)
            closed[] && return
            if status == :ok
                browser_ready[] = true
            else
                render_error[] = ErrorException("The chart did not finish loading in the browser.")
            end
        end
    end
    Bonito.onload(session, res, js"""function(element){
        $(frontend_loaded).notify(true);
    }""")
    return (; dom = res, formula_defaults, formula_toggle, formula_values, mapping,
        mapping_controls, channel_chosen, channel_select, selected_event, event_select,
        ERP_effects, ERP_event_effects, ERP_data, selected_positions, series_options,
        erp_collapsed, series_collapsed, panel_visibility, topoplot_series_dom,
        rendered, render_error, browser_ready, effects_count, series_builds,
        reset_view! = reset_all_axes!, figure = fig)
end
