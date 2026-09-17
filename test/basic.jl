begin
    dataS, evts, _pos2d = build_synthetic_erp_data(4; n_repeats = 20)
    dataS = dataS[:, 1:10:end, :]
    formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
    times = range(0, length = size(dataS, 2), step = 1 / 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
    positions = TopoPlots.labels2positions(["Fp1", "Fp2", "C3", "C4"])
end

struct FakeMultiFormulaModel
    formulas::Vector{Any}
end

Unfold.formulas(model::FakeMultiFormulaModel) = model.formulas

struct FakeTimeExpandedTerm
    term::Any
end

@testset "basic test" begin
    ERPExplorer.explore(model; positions = positions)
    ERPExplorer.explore(model; positions = positions, topoplot_series = true)
    ERPExplorer.explore(model; positions = nothing)
end

@testset "axis_options" begin
    ERPExplorer.explore(
        model;
        positions = positions,
        axis_options = Dict(
            :x_unit => :ms,
            :xlabel => "Time (ms)",
            :ylabel => "Amplitude (uV)",
            :xticks => -200:200:800,
            :xtickformat => nothing,
            :ytickformat => nothing,
            :xscale => nothing,
            :yscale => nothing,
        ),
    )
end

@testset "plot marker size scaling" begin
    @test ERPExplorer.scaled_plot_markersize((700, 600)) == 10.0

    small_marker = ERPExplorer.scaled_plot_markersize((350, 300))
    @test 4.0 <= small_marker < 10.0

    large_marker = ERPExplorer.scaled_plot_markersize((1400, 1200))
    @test 10.0 < large_marker <= 24.0

    @test ERPExplorer.scaled_plot_markersize((700, 600); facet_count = 4) == 5.0
    @test ERPExplorer.scaled_plot_markersize((700, 600); facet_count = 100) == 4.0
    @test ERPExplorer.scaled_plot_markersize((1400, 1200); facet_count = 4) == 10.0
    @test ERPExplorer.scaled_plot_markersize((7000, 6000)) == 24.0
end

@testset "plot linewidth scaling" begin
    @test ERPExplorer.scaled_plot_linewidth((700, 600)) == 1.5
    @test ERPExplorer.scaled_plot_linewidth((700, 600); facet_count = 4) == 0.75
    @test ERPExplorer.scaled_plot_linewidth((700, 600); facet_count = 100) == 0.75
    @test ERPExplorer.scaled_plot_linewidth((1400, 1200); facet_count = 4) == 1.5
end

@testset "continuous slider widgets" begin
    slider_range = ERPExplorer.continuous_slider_range(0.001234, 0.009876)
    @test length(slider_range) == 101
    @test first(slider_range) == 0.001234
    @test last(slider_range) == 0.009876

    swapped_range = ERPExplorer.continuous_slider_range(2.0, 1.0; steps = 11)
    @test first(swapped_range) == 1.0
    @test last(swapped_range) == 2.0
    @test length(swapped_range) == 11

    lo, hi = ERPExplorer.normalize_continuous_bounds(1.0, 1.0)
    @test lo < 1.0 < hi
    @test_throws ArgumentError ERPExplorer.continuous_slider_range(0.0, 1.0; steps = 1)

    slider = ERPExplorer.widget(slider_range)
    @test slider isa ERPExplorer.SignificantRangeSlider
    @test slider.digits[] == 3
    @test slider.tooltips[]
end

@testset "ERP layer visibility" begin
    @test ERPExplorer.erp_layer_visibility(nothing) ==
          (show_lines = true, show_markers = true)
    @test ERPExplorer.erp_layer_visibility(Dict{Symbol,Any}()) ==
          (show_lines = true, show_markers = true)
    @test ERPExplorer.erp_layer_visibility(
        Dict{Symbol,Any}(:show_lines => false, :show_markers => true),
    ) == (show_lines = false, show_markers = true)
    @test ERPExplorer.erp_layer_visibility(
        Dict{Symbol,Any}(:show_lines => true, :show_markers => false),
    ) == (show_lines = true, show_markers = false)
    @test ERPExplorer.erp_layer_visibility(
        Dict{Symbol,Any}(:show_lines => false, :show_markers => false),
    ) == (show_lines = true, show_markers = false)
end

@testset "categorical style palettes" begin
    marker_palette = ERPExplorer.categorical_marker_palette()
    @test length(marker_palette) >= length(BENCHMARK_FRUITS)
    @test marker_palette[1:length(BENCHMARK_FRUITS)] == Any[
        :circle,
        :rect,
        :diamond,
        :utriangle,
        :cross,
        :xcross,
        :star5,
        :vline,
        :hline,
        '#',
    ]
    @test length(ERPExplorer.categorical_linestyle_palette()) >= length(BENCHMARK_FRUITS)
end

@testset "continuous colorbar ticks" begin
    @test ERPExplorer.format_sigdigits_down(123.456) == "123"
    @test ERPExplorer.format_sigdigits_down(12.345) == "12.3"
    @test ERPExplorer.format_sigdigits_down(0.012345) == "0.0123"
    @test ERPExplorer.format_sigdigits_down(-12.345) == "-12.4"

    tick_positions, tick_labels = ERPExplorer.continuous_colorbar_ticks((0.12345, 99.987))
    @test length(tick_positions) == 5
    @test tick_positions[1] == 0.12345
    @test tick_positions[3] ≈ (0.12345 + 99.987) / 2
    @test tick_positions[end] == 99.987
    @test tick_labels == ["0.123", "25", "50", "75", "99.9"]
end

@testset "multi-formula variable extraction" begin
    fruit_model = Unfold.fit(
        UnfoldModel,
        @formula(0 ~ 1 + fruit),
        evts,
        dataS,
        times,
    )
    luminance_model = Unfold.fit(
        UnfoldModel,
        @formula(0 ~ 1 + luminance),
        evts,
        dataS,
        times,
    )
    fake_model = FakeMultiFormulaModel(
        Any[
            Unfold.formulas(fruit_model)...,
            (rhs = FakeTimeExpandedTerm(Unfold.formulas(luminance_model)[1].rhs),),
        ],
    )
    variable_names = first.(ERPExplorer.extract_variables(fake_model))
    @test :fruit in variable_names
    @test :luminance in variable_names
end

@testset "topoplot series helpers" begin
    variables = ERPExplorer.extract_variables(model)
    var_types = map(x -> x[2][3], variables)
    var_names = first.(variables)
    categorical_terms = var_names[var_types .== :CategoricalTerm]
    continuous_terms = var_names[ERPExplorer.is_continuous_like.(var_types)]

    payload = ERPExplorer.build_ERP_payload(
        model,
        [:fruit => (true, BENCHMARK_FRUITS, :CategoricalTerm)],
        1,
    )
    @test all(payload.data.channel .== 1)
    @test length(unique(payload.all_data.channel)) == length(positions)
    @test nrow(payload.all_data) > nrow(payload.data)

    baseline = effects(Dict(:dummy => ["dummy"]), model)
    baseline_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = baseline, all_data = baseline, active_terms = Set{Symbol}()),
        positions,
        categorical_terms,
        continuous_terms,
    )
    @test baseline_summary.status == :ok
    @test baseline_summary.groups == ["All discrete terms"]
    @test !(:row in keys(baseline_summary.mapping))
    @test ERPExplorer.topoplot_series_available(baseline_summary)
    @test ERPExplorer.dashboard_panel_visibility(false, false, true) ==
          (show_erp = true, show_series = true)
    @test ERPExplorer.dashboard_panel_visibility(true, false, true) ==
          (show_erp = false, show_series = true)
    @test ERPExplorer.dashboard_panel_visibility(false, true, true) ==
          (show_erp = true, show_series = false)
    @test ERPExplorer.dashboard_panel_visibility(true, false, false) ==
          (show_erp = true, show_series = false)
    @test ERPExplorer.dashboard_panel_visibility(true, true, true) ==
          (show_erp = true, show_series = false)

    fruit = effects(Dict(:fruit => BENCHMARK_FRUITS), model)
    fruit_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = fruit, all_data = fruit, active_terms = Set([:fruit])),
        positions,
        categorical_terms,
        continuous_terms,
    )
    @test fruit_summary.status == :ok
    @test length(fruit_summary.groups) == length(BENCHMARK_FRUITS)
    @test fruit_summary.mapping.row == :topoplot_group

    mapped_fruit_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = fruit, all_data = fruit, active_terms = Set{Symbol}()),
        positions,
        categorical_terms,
        continuous_terms;
        additional_active_terms = ERPExplorer.mapped_categorical_terms(
            Dict(:color => :fruit, :marker => :none, :show_lines => true),
        ),
    )
    @test mapped_fruit_summary.status == :ok
    @test length(mapped_fruit_summary.groups) == length(BENCHMARK_FRUITS)
    @test mapped_fruit_summary.mapping.row == :topoplot_group

    fruit_animal = effects(
        Dict(:fruit => BENCHMARK_FRUITS, :animal => ["cat", "dog"]),
        model,
    )
    fruit_animal_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = fruit_animal, all_data = fruit_animal, active_terms = Set([:fruit, :animal])),
        positions,
        categorical_terms,
        continuous_terms,
    )
    @test fruit_animal_summary.status == :ok
    @test length(fruit_animal_summary.groups) == 2 * length(BENCHMARK_FRUITS)
    @test fruit_animal_summary.mapping.row == :topoplot_group

    luminance = effects(Dict(:luminance => [0.0, 100.0]), model)
    luminance_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = luminance, all_data = luminance, active_terms = Set([:luminance])),
        positions,
        categorical_terms,
        continuous_terms,
    )
    @test luminance_summary.status == :disabled
    @test occursin("discrete", luminance_summary.message)
    @test !ERPExplorer.topoplot_series_available(luminance_summary)

    mismatch_summary = ERPExplorer.prepare_topoplot_series_data(
        (data = fruit, all_data = fruit, active_terms = Set([:fruit])),
        positions[1:2],
        categorical_terms,
        continuous_terms,
    )
    @test mismatch_summary.status == :disabled
    @test occursin("positions", mismatch_summary.message)

    count_options = ERPExplorer.topoplot_series_count_options(
        (; bin_num = 5, visual = (; label_scatter = false)),
        7,
    )
    @test count_options.bin_num == 7
    @test !(:bin_width in keys(count_options))
    @test count_options.visual == (; label_scatter = false)
end

@testset "real-data loader helpers" begin
    labels = ["Fp1", "Fp2", "C3", "C4"]
    model_path = joinpath(mktempdir(), "synthetic_unfold.jld2")
    JLD2.jldsave(model_path; model = model, channel_labels = labels)

    loaded = ERPExplorer.load_unfold_jld2(model_path)
    @test loaded.model isa UnfoldModel
    @test loaded.positions == TopoPlots.labels2positions(labels)
    @test isempty(loaded.warnings)

    launcher_cfg = parse_harness_config(
        ["--mode=serve", "--data-dir=$(dirname(model_path))"];
        script_dir = TEST_DIR,
    )
    sources = DashboardBenchHarness.launcher_sources([model_path])
    @test sources[1].kind == :synthetic
    @test DashboardBenchHarness.is_synthetic_launcher_source(sources[1].value)
    @test sources[2].kind == :jld2
    @test sources[2].value == model_path
    @test build_real_data_launcher_app(launcher_cfg) isa Bonito.App
    empty_launcher_cfg = parse_harness_config(
        ["--mode=serve", "--data-dir=$(mktempdir())"];
        script_dir = TEST_DIR,
    )
    @test build_real_data_launcher_app(empty_launcher_cfg) isa Bonito.App

    explicit = ERPExplorer.load_unfold_jld2(model_path; model_key = "model")
    @test explicit.model isa UnfoldModel

    no_labels_path = joinpath(mktempdir(), "synthetic_unfold_no_labels.jld2")
    JLD2.jldsave(no_labels_path; model = model)
    no_labels = ERPExplorer.load_unfold_jld2(no_labels_path)
    @test isnothing(no_labels.positions)
    @test any(occursin("No channel labels", warning) for warning in no_labels.warnings)

    labels_path = joinpath(mktempdir(), "labels.tsv")
    open(labels_path, "w") do io
        println(io, "index\tlabel")
        println(io, "2\tFp2")
        println(io, "1\tFp1")
        println(io, "3\tC3")
        println(io, "4\tC4")
    end
    from_file = ERPExplorer.load_unfold_jld2(
        no_labels_path;
        channel_labels_file = labels_path,
    )
    @test from_file.positions == TopoPlots.labels2positions(labels)
end

@testset "event filtering helpers" begin
    event_data = DataFrame(
        yhat = [1.0, 2.0, 3.0, 4.0],
        channel = [1, 1, 2, 2],
        time = [0.0, 0.0, 0.0, 0.0],
        eventname = ["stimulus", "saccade", "stimulus", "saccade"],
    )
    payload = (data = event_data, all_data = event_data, active_terms = Set{Symbol}())

    @test ERPExplorer.event_selection_values(payload) == ["saccade", "stimulus"]
    @test ERPExplorer.event_selection_index(["saccade", "stimulus"], "stimulus") == 2
    @test ERPExplorer.event_selection_index(["saccade", "stimulus"], "missing") == 1

    stimulus_payload = ERPExplorer.filter_ERP_event_payload(payload, "stimulus")
    @test all(stimulus_payload.all_data.eventname .== "stimulus")
    @test length(unique(stimulus_payload.all_data.channel)) == 2

    channel_payload = ERPExplorer.filter_ERP_payload(stimulus_payload, 1)
    @test nrow(channel_payload.data) == 1
    @test nrow(channel_payload.all_data) == 2
end

@testset "update_grid accepts plot_size" begin
    variables = ERPExplorer.extract_variables(model)
    formula_values = [k => ERPExplorer.value_range(v) for (k, v) in variables]
    var_types = map(x -> x[2][3], variables)
    var_names = first.(variables)
    categorical_terms = var_names[var_types .== :CategoricalTerm]
    continuous_terms = var_names[ERPExplorer.is_continuous_like.(var_types)]
    mapping = Dict(:color => :none, :marker => :none, :linestyle => :none, :col => :none, :row => :none)

    yhats = effects(
        Dict(
            :luminance => [0.0, 100.0],
            :fruit => BENCHMARK_FRUITS,
            :animal => ["cat", "dog"],
        ),
        model,
    )
    filter!(row -> row.channel == 1, yhats)

    grid = ERPExplorer.update_grid(
        (data = yhats, active_terms = Set([:luminance, :fruit, :animal])),
        formula_values,
        categorical_terms,
        continuous_terms,
        merge(mapping, Dict(:marker => :fruit, :linestyle => :animal, :row => :fruit, :col => :animal));
        plot_size = (1400, 1200),
    )
    @test !isnothing(grid)
end
