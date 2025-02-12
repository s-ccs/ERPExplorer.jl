using ERPExplorer
using Test
using UnfoldSim
using DataFrames
using Random
using Unfold
using Bonito
using JuliaFormatter
using TopoPlots

path = dirname(Base.current_project())
include(path * "/docs/gen_data.jl")
