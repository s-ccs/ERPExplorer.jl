"""
    default_bench_report_path(config)

Build a timestamped CSV path for offline benchmark reports.
"""
function default_bench_report_path(config::HarnessConfig)
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    return joinpath(config.reports_dir, "bench_report_$(timestamp).csv")
end

"""
    default_live_report_path(config, scenario_path)

Build a timestamped CSV path for live benchmark auto reports.
"""
function default_live_report_path(config::HarnessConfig, scenario_path::AbstractString)
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    stem = splitext(basename(scenario_path))[1]
    return joinpath(config.reports_dir, "$(stem)_report_$(timestamp).csv")
end

"""
    write_bench_csv(path, rows)

Write offline benchmark rows to CSV.
"""
function write_bench_csv(path::AbstractString, rows)
    open(path, "w") do io
        println(
            io,
            "action_id,success,runs_completed,runs_requested,effects_median_ms,update_grid_median_ms,total_median_ms,error_message",
        )
        for row in rows
            err = replace(row.error_message, '\n' => ' ')
            err = replace(err, '"' => '\'')
            println(
                io,
                string(
                    row.action_id,
                    ",",
                    row.success,
                    ",",
                    row.runs_completed,
                    ",",
                    row.runs_requested,
                    ",",
                    row.effects_median_ms,
                    ",",
                    row.update_grid_median_ms,
                    ",",
                    row.total_median_ms,
                    ",\"",
                    err,
                    "\"",
                ),
            )
        end
    end
end

"""
    write_live_csv(path, rows)

Write live action timing rows to CSV.
"""
function write_live_csv(path::AbstractString, rows)
    open(path, "w") do io
        println(io, "sequence,event_source,action_id,effects_ms,plot_layout_ms,total_ms")
        for row in rows
            println(
                io,
                string(
                    row.sequence,
                    ",",
                    row.event_source,
                    ",",
                    row.action_id,
                    ",",
                    row.effects_ms,
                    ",",
                    row.plot_layout_ms,
                    ",",
                    row.total_ms,
                ),
            )
        end
    end
end
