@testset "Live playback timing state" begin
    cfg = HarnessConfig(
        MODE_BENCH_LIVE_AUTO,
        DEFAULT_HOST,
        DEFAULT_PORT,
        DEFAULT_SFREQ,
        DEFAULT_BENCH_REPEATS,
        DEFAULT_BENCH_WARMUP,
        DEFAULT_BENCH_CHANNEL,
        "",
        0.0,
        DEFAULT_LIVE_STEP_DELAY_SEC,
        DEFAULT_LIVE_ACTION_TIMEOUT_SEC,
        joinpath(@__DIR__, "livebench_actions_default.txt"),
        "",
        mktempdir(),
    )

    instant_state = DashboardBenchHarness.create_live_playback_state(
        cfg,
        ["baseline"],
        joinpath(mktempdir(), "instant.csv"),
    )
    DashboardBenchHarness.begin_auto_action!(instant_state, "baseline", false)
    @test DashboardBenchHarness.record_instant_action!(instant_state)
    @test length(instant_state.rows) == 1
    @test instant_state.rows[1].action_id == "baseline"
    @test isnan(instant_state.rows[1].effects_ms)
    @test isnan(instant_state.rows[1].plot_layout_ms)
    @test instant_state.auto_completed[] == 1
    @test instant_state.auto_timed_out[] == 0

    gate_state = DashboardBenchHarness.create_live_playback_state(
        cfg,
        String[],
        joinpath(mktempdir(), "gate.csv"),
    )
    @test !DashboardBenchHarness.live_auto_can_start(gate_state)
    DashboardBenchHarness.mark_initial_render_ready!(gate_state)
    @test DashboardBenchHarness.live_auto_can_start(gate_state)

    render_state = DashboardBenchHarness.create_live_playback_state(
        cfg,
        ["toggle_luminance_on"],
        joinpath(mktempdir(), "render.csv"),
    )
    render_state.render_settle_delay_sec = 0.02
    DashboardBenchHarness.begin_auto_action!(render_state, "toggle_luminance_on", true)
    DashboardBenchHarness.mark_effects_ready!(render_state, 1.0)
    DashboardBenchHarness.on_render_completed!(render_state, 2.0)
    DashboardBenchHarness.mark_effects_ready!(render_state, 3.0)
    DashboardBenchHarness.on_render_completed!(render_state, 4.0)
    @test DashboardBenchHarness.wait_for_action_completion!(render_state, 1.0)
    @test length(render_state.rows) == 1
    @test render_state.rows[1].action_id == "toggle_luminance_on"
    @test render_state.rows[1].effects_ms == 3.0
    @test render_state.rows[1].plot_layout_ms == 4.0
    @test render_state.auto_completed[] == 1
    @test render_state.auto_timed_out[] == 0

    timeout_state = DashboardBenchHarness.create_live_playback_state(
        cfg,
        ["toggle_luminance_on"],
        joinpath(mktempdir(), "timeout.csv"),
    )
    DashboardBenchHarness.begin_auto_action!(timeout_state, "toggle_luminance_on", true)
    @test !DashboardBenchHarness.wait_for_action_completion!(timeout_state, 0.01)
    @test length(timeout_state.rows) == 1
    @test timeout_state.rows[1].action_id == "toggle_luminance_on"
    @test isnan(timeout_state.rows[1].effects_ms)
    @test isnan(timeout_state.rows[1].plot_layout_ms)
    @test timeout_state.auto_completed[] == 0
    @test timeout_state.auto_timed_out[] == 1

    render_timeout_state = DashboardBenchHarness.create_live_playback_state(
        cfg,
        ["toggle_luminance_on"],
        joinpath(mktempdir(), "render_timeout.csv"),
    )
    DashboardBenchHarness.begin_auto_action!(render_timeout_state, "toggle_luminance_on", true)
    render_timeout_state.auto_started[] = true
    @test DashboardBenchHarness.handle_live_render_error!(
        render_timeout_state,
        "Timed out",
    ) == :timeout
    @test length(render_timeout_state.rows) == 1
    @test render_timeout_state.auto_timed_out[] == 1

    @test DashboardBenchHarness.is_closed_render_error("Screen Session uninitialized")
    @test DashboardBenchHarness.is_closed_render_error("Session status: SOFT_CLOSED")
    @test DashboardBenchHarness.is_render_transport_timeout("Timed out")
    @test DashboardBenchHarness.handle_live_render_error!(
        render_timeout_state,
        "unrelated render failure",
    ) == :rethrow
end
