include("lib/regression_fixture.jl")

@testset "Saved models retain predictions" begin
    fixture = regression_fixture()
    original = effects(Dict(:dummy => ["dummy"]), fixture.model)
    mktempdir() do dir
        file = joinpath(dir, "unfold.jld2")
        Unfold.save(file, fixture.model)
        loaded = ERPExplorer.load_unfold_jld2(file; channel_labels = fixture.labels)
        @test effects(Dict(:dummy => ["dummy"]), loaded.model).yhat ≈ original.yhat
        @test loaded.positions == fixture.positions
        stripped = JLD2.load(file, "uf")
        nested = joinpath(dir, "nested.jld2")
        JLD2.jldsave(nested; models = (first = stripped, second = fixture.model))
        @test occursin("models.first", first(ERPExplorer.load_unfold_jld2(nested).warnings))
        for key in ("models.first", "models.second")
            chosen = ERPExplorer.load_unfold_jld2(nested; model_key = key)
            @test effects(Dict(:dummy => ["dummy"]), chosen.model).yhat ≈ original.yhat
        end
        grouped = joinpath(dir, "grouped.jld2")
        JLD2.jldopen(grouped, "w") do f
            f["group/model"] = fixture.model
        end
        @test ERPExplorer.load_unfold_jld2(grouped; model_key = "group/model").model isa UnfoldModel
        @test_throws ArgumentError ERPExplorer.load_unfold_jld2(file; channel_labels = fixture.labels[1:3])
        unknown = ERPExplorer.load_unfold_jld2(file; channel_labels = ["Fp1", "Fp2", "C3", "UNKNOWN"])
        @test isnothing(unknown.positions)
        @test !isempty(unknown.warnings)
    end
end

@testset "Channel identity is preserved" begin
    for labels in (["Fp1", missing, "C3"], ["Fp1", "", "C3"], ["Fp1", "fp1"])
        @test_throws ArgumentError ERPExplorer.normalize_channel_labels(labels)
    end
    @test_throws ArgumentError ERPExplorer.maybe_channel_labels([(label = "Fp1",), (label = missing,)])
    @test ERPExplorer.channel_labels_from_table(DataFrame(index = [4, 2, 1, 3], label = ["C4", "Fp2", "Fp1", "C3"])) == ["Fp1", "Fp2", "C3", "C4"]
    for indices in ([1, 3], [1, 1], [0, 1], ["1", "bad"])
        @test_throws ArgumentError ERPExplorer.channel_labels_from_table(DataFrame(index = indices, label = ["Fp1", "Fp2"]))
    end
    @test_throws ArgumentError ERPExplorer.validate_channel_positions([Point2f(0, 0)], 4)
    @test_throws ArgumentError ERPExplorer.validate_channel_positions(Dict("bad" => [Point2f(0, 0)]), 4)
end

@testset "Shared predictors across real event formulas" begin
    fixture = regression_fixture(; multievent = true, different_bounds = true)
    variables = Dict(ERPExplorer.extract_variables(fixture.model))
    @test variables[:luminance][4].min == 1000.0
    @test variables[:luminance][4].max == 1101.0
    invalid = regression_fixture(; multievent = true, different_levels = true)
    @test_throws ArgumentError ERPExplorer.extract_variables(invalid.model)
    @test_throws ArgumentError ERPExplorer.explore(invalid.model)
    @test length(ERPExplorer.event_selection_values(effects(Dict(:dummy => ["dummy"]), fixture.model))) == 2
end

@testset "Time windows are honored" begin
    options, _ = ERPExplorer.topoplot_series_controls((; bin_width = 0.025))
    @test options[].bin_width == 0.025
    @test isnothing(options[].bin_num)
    @test_throws ArgumentError ERPExplorer.validate_series_options((; bin_width = 0.1, bin_num = 3))
    @test_throws ArgumentError ERPExplorer.validate_series_options((; bin_width = 0.0))
    @test_throws ArgumentError ERPExplorer.validate_series_options((; bin_num = 7.2))
    @test_throws ArgumentError ERPExplorer.validate_series_options((; bin_num = 25))
    fixture = regression_fixture()
    data = effects(Dict(:fruit => ["apple", "pear"]), fixture.model)
    summary = ERPExplorer.prepare_topoplot_series_data((; data, all_data = data, active_terms = Set([:fruit])), fixture.positions, [:fruit], [:luminance])
    @test ERPExplorer.topoplot_series_plot_count(summary, (; bin_num = 24)) == 48
    @test ERPExplorer.topoplot_series_widget(summary, fixture.positions; options = (; bin_num = 24), max_plots = 10) !== nothing
end

@testset "Benchmark failures fail the run" begin
    fixture = regression_fixture()
    mktempdir() do dir
        path = joinpath(dir, "failed.csv")
        config = parse_harness_config(["--bench", "--bench-warmup=0", "--bench-repeats=1", "--bench-out=$(path)"]; script_dir = TEST_DIR)
        @test_throws ErrorException run_offline_benchmark(fixture.model, config; update_plot = (args...) -> error("intentional render failure"))
        @test isfile(path)
        @test occursin("false", read(path, String))
    end
end

function wait_dashboard(dashboard, predicate; timeout = 60)
    status = timedwait(() -> !isnothing(dashboard.render_error[]) || predicate(), timeout; pollint = 0.02)
    @test isnothing(dashboard.render_error[])
    @test status == :ok
end

@testset "Production dashboard integration" begin
    fixture = regression_fixture(; multievent = true)
    session = Bonito.Session(Bonito.NoConnection(); asset_server = Bonito.NoServer())
    d = ERPExplorer.build_dashboard(session, fixture.model; positions = fixture.positions,
        size = (600, 300), fit_window = false,
        axis_options = Dict(:x_unit => :s, :xlimits => (-0.1, 0.1), :ylimits => (-1.0, 5.0)))
    try
        @test !isnothing(d.rendered[])
        @test d.effects_count[] == 1
        # Moving an inactive predictor does not change the prediction request.
        toggle = deepcopy(d.formula_toggle[])
        i = findfirst(p -> p.first == :luminance, toggle)
        toggle[i] = :luminance => (false, Any[1000.12, 1000.89], :ContinuousTerm)
        d.formula_toggle[] = toggle
        @test d.effects_count[] == 1
        @test d.series_builds[] == 0
        @test !d.panel_visibility[].show_series
        d.channel_select.option_index[] = 3
        @test all(d.ERP_data[].data.channel .== 3)
        @test d.effects_count[] == 1
        d.event_select.option_index[] = 2
        @test all(isequal.(d.ERP_data[].data.eventname, Ref(d.event_select.value[])))
        @test d.effects_count[] == 1
        d.formula_defaults[:fruit][] = true
        @test d.effects_count[] == 2
        ERPExplorer.set_mapping_control!(d.mapping_controls, :show_markers, false)
        ERPExplorer.set_mapping_control!(d.mapping_controls, :color, :fruit)
        @test !d.mapping[][:show_markers]
        ERPExplorer.set_mapping_control!(d.mapping_controls, :show_lines, false)
        @test d.mapping[][:show_markers]
        d.series_options[] = (; bin_num = 2)
        d.series_collapsed[] = false
        wait_dashboard(d, () -> d.series_builds[] == 1)
        d.series_collapsed[] = true
        d.series_collapsed[] = false
        ERPExplorer.set_mapping_control!(d.mapping_controls, :marker, :fruit)
        sleep(0.3)
        @test d.series_builds[] == 1
        d.series_options[] = (; bin_width = 0.025)
        wait_dashboard(d, () -> d.series_builds[] == 2)
        d.reset_view!()
        axes = filter(x -> x isa ERPExplorer.Makie.Axis, d.figure.figure.content)
        @test !isempty(axes)
        @test all(ax -> ax.limits[] == ((-0.1, 0.1), (-1.0, 5.0)), axes)
        html = sprint(show, MIME"text/html"(), Bonito.session_dom(session, Bonito.jsrender(session, d.dom)))
        @test occursin("continuous-slider", html)
        @test occursin("nouislider.min.js", html)
    finally
        close(session)
    end
    @test isempty(session.deregister_callbacks)
    fallback_session = Bonito.Session(Bonito.NoConnection(); asset_server = Bonito.NoServer())
    try
        fallback = ERPExplorer.build_dashboard(fallback_session, fixture.model; positions = nothing, topoplot_series = false)
        fallback.channel_select.option_index[] = 4
        @test all(fallback.ERP_data[].data.channel .== 4)
        @test length(fallback.channel_select.options[]) == 4
    finally
        close(fallback_session)
    end
end
