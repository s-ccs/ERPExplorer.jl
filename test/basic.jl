begin
    dataS, evts, _pos2d = build_synthetic_erp_data()
    formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
    times = range(0, length = size(dataS, 2), step = 1 / 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
    _, positions = TopoPlots.example_data()
end

@testset "basic test" begin
    ERPExplorer.explore(model; positions = positions)
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
            :fruit => ["orange", "banana"],
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
