"""
    run_offline_benchmark(model, config)

Run the default bench scenario and write a CSV report.
Returns collected row records.
"""
function run_offline_benchmark(model, config::HarnessConfig)
    variables = ERPExplorer.extract_variables(model)
    formula_values = [k => ERPExplorer.value_range(v) for (k, v) in variables]
    var_types = map(x -> x[2][3], variables)
    var_names = first.(variables)
    categorical_terms = var_names[var_types .== :CategoricalTerm]
    continuous_terms = var_names[ERPExplorer.is_continuous_like.(var_types)]

    action_state = initialize_bench_state(variables, config.bench_channel)

    scenario_ids = default_bench_scenario()
    ensure_registered_action_ids(scenario_ids; required_scope = ACTION_SCOPE_BENCH, source_label = "default bench scenario")

    function compute_effects_df()
        yhat_dict = Dict{Symbol,Any}()
        active_terms = Set{Symbol}()
        for (term, enabled) in action_state.active_terms
            if enabled
                push!(active_terms, term)
                yhat_dict[term] = ERPExplorer.widget_value(
                    action_state.selected_values[term],
                    action_state.term_types[term],
                )
            end
        end
        if isempty(yhat_dict)
            yhat_dict = Dict(:dummy => ["dummy"])
        end

        yhats = effects(yhat_dict, model)
        filter!(row -> row.channel == action_state.channel[], yhats)
        return (data = yhats, active_terms = active_terms)
    end

    function run_once()
        t0 = time_ns()
        t1 = time_ns()
        yhats = compute_effects_df()
        effects_ms = (time_ns() - t1) / 1e6
        t2 = time_ns()
        ERPExplorer.update_grid(
            yhats,
            formula_values,
            categorical_terms,
            continuous_terms,
            action_state.mapping,
        )
        grid_ms = (time_ns() - t2) / 1e6
        total_ms = (time_ns() - t0) / 1e6
        return effects_ms, grid_ms, total_ms
    end

    for _ = 1:config.bench_warmup
        run_once()
    end

    rows = NamedTuple[]
    println("Running GUI-action benchmark")
    println(
        "repeats=$(config.bench_repeats), warmup=$(config.bench_warmup), channel=$(config.bench_channel)",
    )
    println(rpad("action", 28), rpad("success", 8), rpad("runs", 6), rpad("effects", 12), rpad("grid", 12), "total")
    println(repeat("-", 74))

    for action_id in scenario_ids
        apply_bench_action!(action_state, action_id)

        ok = true
        err = ""
        effects_samples = Float64[]
        grid_samples = Float64[]
        total_samples = Float64[]
        runs_completed = 0

        for _ = 1:config.bench_repeats
            try
                effects_ms, grid_ms, total_ms = run_once()
                push!(effects_samples, effects_ms)
                push!(grid_samples, grid_ms)
                push!(total_samples, total_ms)
                runs_completed += 1
            catch e
                ok = false
                err = sprint(showerror, e, catch_backtrace())
                break
            end
        end

        if ok
            eff = median(effects_samples)
            grd = median(grid_samples)
            tot = median(total_samples)
            push!(
                rows,
                (
                    action_id = action_id,
                    success = true,
                    runs_completed = runs_completed,
                    runs_requested = config.bench_repeats,
                    effects_median_ms = eff,
                    update_grid_median_ms = grd,
                    total_median_ms = tot,
                    error_message = "",
                ),
            )
            @printf(
                "%-28s %-6s %-6d %9.2fms %9.2fms %9.2fms\n",
                action_id,
                "true",
                runs_completed,
                eff,
                grd,
                tot,
            )
        else
            push!(
                rows,
                (
                    action_id = action_id,
                    success = false,
                    runs_completed = runs_completed,
                    runs_requested = config.bench_repeats,
                    effects_median_ms = NaN,
                    update_grid_median_ms = NaN,
                    total_median_ms = NaN,
                    error_message = err,
                ),
            )
            @printf(
                "%-28s %-6s %-6d %9s   %9s   %9s\n",
                action_id,
                "false",
                runs_completed,
                "ERR",
                "ERR",
                "ERR",
            )
            println("  error: ", split(err, '\n')[1])
        end
    end

    output_path = isempty(config.bench_out) ? default_bench_report_path(config) : config.bench_out
    mkpath(dirname(output_path))
    write_bench_csv(output_path, rows)
    println("Wrote benchmark CSV: ", output_path)

    return rows
end
