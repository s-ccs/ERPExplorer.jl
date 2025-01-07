begin
    using Pkg
    Pkg.activate(".")
    Pkg.status()
    using Revise
    using ERPExplorer
    using UnfoldSim
    using DataFrames
    using Random
    using Unfold
    using Bonito
    using JuliaFormatter
    using TopoPlots
end


include("gen_data.jl")
#formulaS = @formula(0 ~ 1 +luminance + contrast + saccade_amplitude + string + animal + fruit + color)
formulaS = @formula(0 ~ 1 + animal + fruit)
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
dataS, evts, pos2d = gen_data()
times = range(0, length = size(dataS, 2), step = 1 ./ 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

_, positions = TopoPlots.example_data()
explore(model; positions = positions)

#format_file("scripts/gen_data.jl")
begin
    using Pkg
    Pkg.activate(".")
    Pkg.status()
end

include("/store/users/mikheev/projects/erpexplorer_dev/dev/ERPExplorer/docs/make.jl")

using JuliaFormatter
begin
    test_entries = readdir("./test")
    cd("./test")
    for i in test_entries
        format_file(i)
    end
    src_entries = readdir("../src")
    cd("../src")
    for i in src_entries
        format_file(i)
    end
    docs_entries = readdir("../docs")
    cd("../docs")
    for i in docs_entries
        format_file(i)
    end
end
