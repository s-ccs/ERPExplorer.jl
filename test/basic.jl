begin
    dataS, evts, pos2d = gen_data()
    formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
    times = range(0, length = size(dataS, 2), step = 1 ./ 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
    _, positions = TopoPlots.example_data()
end

@testset "basic test" begin
    ERPExplorer.explore(model; positions = positions)
end
