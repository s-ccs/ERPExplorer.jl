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

@testset "axis_options" begin
    ERPExplorer.explore(model; positions = positions,
        axis_options = Dict(
            :x_unit => :ms,
            :xlabel => "Time pupupu",
            :ylabel => "Amplitude pupupu",
           # :xlimits => (0, 400),
            #:ylimits => (-5, 5),
            :xticks => -200:200:800,
            #:yticks => -5:2.5:5,
            :xtickformat => nothing,
            :ytickformat => nothing,
            :xscale => nothing,
            :yscale => nothing,
        ),
    )
end
#gui = ERPExplorer.explore(model; positions = positions)