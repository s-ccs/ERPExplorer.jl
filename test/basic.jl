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
