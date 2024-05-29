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
end

#formulaS = @formula(0 ~ 1 +luminance + contrast + saccade_amplitude + string + animal + fruit + color)
formulaS = @formula(0 ~ 1 + animal + fruit)
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
dataS, evts, pos2d = gen_data()
times = range(0, length=size(dataS, 2), step=1 ./ 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

explore(model; positions=pos2d)

