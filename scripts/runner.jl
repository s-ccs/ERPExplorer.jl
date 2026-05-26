#!/usr/bin/env julia

import Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))

Pkg.activate(@__DIR__)
Pkg.develop(path = ROOT)

using ERPExplorer
using TopoPlots
using Unfold
using WGLMakie

include(joinpath(ROOT, "test", "lib", "synthetic_data.jl"))

dataS, evts, _positions = build_synthetic_erp_data()
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
times = range(0, length = size(dataS, 2), step = 1 / 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

_, positions = TopoPlots.example_data()
WGLMakie.activate!()
display(ERPExplorer.explore(model; positions = positions))
