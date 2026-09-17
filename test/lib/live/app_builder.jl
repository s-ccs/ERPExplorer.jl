"""
    build_live_benchmark_app(model, config; positions, size, fit_window)

Run benchmark playback against the same dashboard used by `ERPExplorer.explore`.
"""
function build_live_benchmark_app(model, config::HarnessConfig;
    positions = nothing, size = (700, 600), fit_window = true)
    action_ids = load_validated_scenario(config.live_actions_file;
        required_scope = ACTION_SCOPE_LIVE, source_label = config.live_actions_file)
    report_path = isempty(config.live_report_file) ?
        default_live_report_path(config, config.live_actions_file) : config.live_report_file
    return App() do session
        playback = create_live_playback_state(config, action_ids, report_path)
        dashboard = ERPExplorer.build_dashboard(session, model; positions, size, fit_window)
        bindings = LiveUiBindings(
            (term, enabled) -> (dashboard.formula_defaults[term][] = enabled),
            (slot, value) -> ERPExplorer.set_mapping_control!(dashboard.mapping_controls, slot, value),
            channel -> (dashboard.channel_select.option_index[] = channel),
            dashboard.reset_view!,
            (option, value) -> begin
                if option == :series
                    dashboard.series_collapsed[] = !value
                elseif option == :bin_num
                    dashboard.series_options[] = ERPExplorer.topoplot_series_count_options(dashboard.series_options[], value)
                elseif option == :event_index
                    dashboard.event_select.option_index[] = value
                else
                    ERPExplorer.set_mapping_control!(dashboard.mapping_controls, option, value)
                end
            end,
        )
        on(session, dashboard.rendered) do timing
            isnothing(timing) && return
            mark_effects_ready!(playback, timing.effects_ms)
            on_render_completed!(playback, timing.plot_layout_ms)
        end
        on(session, dashboard.render_error) do err
            isnothing(err) && return
            if playback.auto_action_inflight[]
                record_failed_action!(playback)
            end
        end
        on(session, dashboard.browser_ready; update = true) do ready
            ready || return
            mark_initial_render_ready!(playback)
            maybe_start_auto_playback!(playback, bindings, config.live_actions_file)
        end
        return dashboard.dom
    end
end
