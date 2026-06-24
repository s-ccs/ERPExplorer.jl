@testset "Action registry consistency" begin
    registry_ids = Set(registered_action_ids())
    live_ids = Set(action_ids_for_scope(ACTION_SCOPE_LIVE))
    bench_ids = Set(action_ids_for_scope(ACTION_SCOPE_BENCH))

    default_live_ids = read_action_scenario(joinpath(@__DIR__, "livebench_actions_default.txt"))
    @test all(id -> id in registry_ids, default_live_ids)
    @test all(id -> id in live_ids, default_live_ids)

    @test all(id -> id in registry_ids, default_bench_scenario())
    @test all(id -> id in bench_ids, default_bench_scenario())

    @test "baseline" in bench_ids
    @test "baseline" in live_ids
    @test !live_action_triggers_render("baseline")
    @test "reset_view" in live_ids
    @test !live_action_triggers_render("reset_view")
    @test live_action_triggers_render("toggle_luminance_on")
    @test "luminance_full_range" in bench_ids
    @test !("luminance_full_range" in live_ids)
end
