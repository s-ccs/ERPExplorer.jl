"""
    build_live_benchmark_app(model, config; positions, size, fit_window)

Build the interactive `bench-live-auto` app.
"""
function build_live_benchmark_app(
    model,
    config::HarnessConfig;
    positions = nothing,
    size = (700, 600),
    fit_window = true,
)
    action_ids = load_validated_scenario(
        config.live_actions_file;
        required_scope = ACTION_SCOPE_LIVE,
        source_label = config.live_actions_file,
    )
    report_path =
        isempty(config.live_report_file) ?
        default_live_report_path(config, config.live_actions_file) :
        config.live_report_file

    playback = create_live_playback_state(config, action_ids, report_path)

    Bonito.set_cleanup_time!(1)
    return App() do
        variables = ERPExplorer.extract_variables(model)
        formula_defaults, formula_toggle, formula_dom, formula_values =
            ERPExplorer.formular_widgets(variables)

        reset_button = Bonito.Button(
            "Reset view";
            style = Styles("padding" => "4px 6px", "min-height" => "24px"),
        )

        var_types = map(x -> x[2][3], variables)
        var_names = first.(variables)
        cat_terms = var_names[var_types .== :CategoricalTerm]
        cont_terms = var_names[ERPExplorer.is_continuous_like.(var_types)]

        mapping, mapping_dom, mapping_controls = build_mapping_controls(var_names, var_types)

        channel_chosen = Observable(1)
        topo_widget = build_topoplot_panel(positions, channel_chosen; size = size .* 0.5)

        ERP_data = Observable{Any}(nothing; ignore_equal_values = true)
        last_effects_ms = Ref{Union{Nothing,Float64}}(nothing)

        onany(formula_toggle, channel_chosen; update = true) do formula_state, chan
            t0 = time_ns()
            yhat_dict = Dict{Symbol,Any}()
            active_terms = Set{Symbol}()
            for (term, value_state) in formula_state
                if !isempty(value_state) && value_state[1] && !isempty(value_state[2])
                    push!(active_terms, term)
                    yhat_dict[term] = ERPExplorer.widget_value(value_state[2], value_state[3])
                end
            end
            if isempty(yhat_dict)
                yhat_dict = Dict(:dummy => ["dummy"])
            end

            yhats = effects(yhat_dict, model)
            filter!(row -> row.channel == chan, yhats)
            last_effects_ms[] = (time_ns() - t0) / 1e6
            ERP_data[] = (data = yhats, active_terms = active_terms)
        end

        function set_term_enabled!(term::Symbol, enabled::Bool)
            if haskey(formula_defaults, term)
                formula_defaults[term][] = enabled
            end
        end
        function set_mapping_slot!(slot::Symbol, value::Symbol)
            if haskey(mapping_controls, slot)
                mapping_controls[slot].value[] = value
            end
        end
        set_channel!(channel::Int) = (channel_chosen[] = channel)
        reset_view!() = (reset_button.value[] = !to_value(reset_button.value))

        bindings = LiveUiBindings(set_term_enabled!, set_mapping_slot!, set_channel!, reset_view!)
        maybe_start_auto!() = maybe_start_auto_playback!(playback, bindings, config.live_actions_file)

        formula_seen = Ref(false)
        syncing_formula_defaults = Ref(false)
        on(formula_toggle) do _
            if !formula_seen[]
                formula_seen[] = true
                return
            end
            syncing_formula_defaults[] && return
            mark_pending_action!(playback, "formula")
        end

        channel_seen = Ref(false)
        on(channel_chosen) do _
            if !channel_seen[]
                channel_seen[] = true
                return
            end
            mark_pending_action!(playback, "topoplot")
        end

        mapping_seen = Ref(false)
        on(mapping) do current_map
            if mapping_seen[]
                mark_pending_action!(playback, "mapping")
            else
                mapping_seen[] = true
            end

            syncing_formula_defaults[] = true
            try
                mapped_terms = Set(value for value in values(current_map) if value != :none)
                for (term, toggle_obs) in formula_defaults
                    if term in mapped_terms && !toggle_obs[]
                        toggle_obs[] = true
                    end
                end
            finally
                syncing_formula_defaults[] = false
            end
        end

        on(ERP_data) do yhats
            if playback.pending_start_ns[] > 0 && yhats !== nothing
                mark_effects_ready!(playback, last_effects_ms[])
            end
        end

        plot_layout = Observable(ERPExplorer.S.GridLayout())
        render_lock = Base.ReentrantLock()
        fig_ref = Ref{Union{Nothing,Makie.FigureAxisPlot}}(nothing)

        render_count = Ref(0)
        Makie.onany_latest(ERP_data, mapping; update = true) do erp_state, mapping_value
            lock(render_lock) do
                t0 = time_ns()
                spec = ERPExplorer.update_grid(
                    erp_state,
                    formula_values,
                    cat_terms,
                    cont_terms,
                    mapping_value;
                    plot_size = size,
                )
                try
                    plot_layout[] = spec
                catch err
                    err_msg = sprint(showerror, err)
                    render_error = handle_live_render_error!(playback, err_msg)
                    if render_error == :closed || render_error == :timeout
                        return
                    end
                    rethrow(err)
                end

                render_count[] += 1
                plot_layout_ms = (time_ns() - t0) / 1e6
                println(
                    "render #",
                    render_count[],
                    " update_grid -> layout in ",
                    round(plot_layout_ms; digits = 2),
                    " ms",
                )

                reset_all_axes!(fig_ref, render_lock)
                on_render_completed!(playback, plot_layout_ms)
                mark_initial_render_ready!(playback)
                maybe_start_auto!()
            end
            return
        end

        css = Asset(joinpath(@__DIR__, "..", "..", "..", "style.css"))
        fig = plot(plot_layout; figure = (size = size,))
        fig_ref[] = fig
        fig_view = fit_window ? WGLMakie.WithConfig(fig; resize_to = :parent) : fig

        on(reset_button.value) do _
            reset_all_axes!(fig_ref, render_lock)
        end

        header_dom = Grid(
            formula_dom,
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
                "height" => "$(1.2 * size[2])px",
                "width" => "$(size[1])px",
                "margin" => "20px",
                "position" => :relative,
            )

        return DOM.div(css, Bonito.TailwindCSS, cards; style = container_style)
    end
end
