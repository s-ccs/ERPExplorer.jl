@testset "CLI config parsing" begin
    script_dir = @__DIR__

    help_cfg = parse_harness_config(["--help"]; script_dir = script_dir)
    @test help_cfg.mode == MODE_HELP

    bench_cfg = parse_harness_config(["--bench"]; script_dir = script_dir)
    @test bench_cfg.mode == MODE_BENCH

    live_cfg = parse_harness_config(
        [
            "--mode=bench-live-auto",
            "--bench-live-delay=1",
            "--bench-live-start-delay=2.5",
            "--bench-live-timeout=30",
        ];
        script_dir = script_dir,
    )
    @test live_cfg.mode == MODE_BENCH_LIVE_AUTO
    @test live_cfg.live_step_delay_sec == 5.0
    @test live_cfg.live_start_delay_sec == 2.5
    @test live_cfg.live_action_timeout_sec == 30.0

    default_live_cfg = parse_harness_config(["--mode=bench-live-auto"]; script_dir = script_dir)
    @test default_live_cfg.live_action_timeout_sec == DEFAULT_LIVE_ACTION_TIMEOUT_SEC

    @test_throws ErrorException parse_harness_config(
        ["--mode=serve", "--bench"];
        script_dir = script_dir,
    )

    @test_throws ErrorException parse_harness_config(
        ["--mode=bench-live"];
        script_dir = script_dir,
    )

    @test_throws ErrorException parse_harness_config(
        ["--does-not-exist"];
        script_dir = script_dir,
    )

    @test_throws ErrorException parse_harness_config(
        ["--bench-repeats=abc"];
        script_dir = script_dir,
    )

    @test_throws ErrorException parse_harness_config(
        ["--mode=bench-live-auto", "--bench-live-timeout=0"];
        script_dir = script_dir,
    )
end
