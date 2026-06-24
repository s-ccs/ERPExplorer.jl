@testset "Report IO helpers" begin
    cfg = HarnessConfig(
        MODE_BENCH,
        DEFAULT_HOST,
        DEFAULT_PORT,
        DEFAULT_SFREQ,
        DEFAULT_BENCH_REPEATS,
        DEFAULT_BENCH_WARMUP,
        DEFAULT_BENCH_CHANNEL,
        "",
        DEFAULT_LIVE_START_DELAY_SEC,
        DEFAULT_LIVE_STEP_DELAY_SEC,
        DEFAULT_LIVE_ACTION_TIMEOUT_SEC,
        joinpath(@__DIR__, "livebench_actions_default.txt"),
        "",
        joinpath(@__DIR__, "reports"),
    )

    bench_path = default_bench_report_path(cfg)
    @test occursin("bench_report_", basename(bench_path))
    @test dirname(bench_path) == cfg.reports_dir

    live_path = default_live_report_path(cfg, cfg.live_actions_file)
    @test occursin("livebench_actions_default_report_", basename(live_path))
    @test dirname(live_path) == cfg.reports_dir

    out_dir = mktempdir()
    bench_csv = joinpath(out_dir, "bench.csv")
    write_bench_csv(
        bench_csv,
        [
            (
                action_id = "baseline",
                success = true,
                runs_completed = 1,
                runs_requested = 1,
                effects_median_ms = 1.0,
                update_grid_median_ms = 2.0,
                total_median_ms = 3.0,
                error_message = "",
            ),
        ],
    )
    @test readlines(bench_csv)[1] ==
          "action_id,success,runs_completed,runs_requested,effects_median_ms,update_grid_median_ms,total_median_ms,error_message"

    live_csv = joinpath(out_dir, "live.csv")
    write_live_csv(
        live_csv,
        [
            (
                sequence = 1,
                event_source = "auto:baseline",
                action_id = "baseline",
                effects_ms = 1.0,
                plot_layout_ms = 2.0,
                total_ms = 3.0,
            ),
        ],
    )
    @test readlines(live_csv)[1] ==
          "sequence,event_source,action_id,effects_ms,plot_layout_ms,total_ms"

    missing_path = joinpath(mktempdir(), "nope.txt")
    @test_throws ErrorException read_action_scenario(missing_path)

    empty_file = joinpath(mktempdir(), "empty_actions.txt")
    open(empty_file, "w") do io
        println(io, "# comments only")
    end
    @test_throws ErrorException read_action_scenario(empty_file)
end
