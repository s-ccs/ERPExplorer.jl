using ERPExplorer
using Test
using Unfold
using UnfoldSim
using Bonito
using DataFrames
using GeometryBasics
using TopoPlots

const TEST_DIR = @__DIR__
include(joinpath(TEST_DIR, "lib", "synthetic_data.jl"))
include(joinpath(TEST_DIR, "lib", "DashboardBenchHarness.jl"))
using .DashboardBenchHarness
