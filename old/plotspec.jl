using Pkg
Pkg.activate(@__DIR__)
#=
# Somehow I need to redo the project if I want to update the branches
rm(joinpath(@__DIR__, "Project.toml"))
rm(joinpath(@__DIR__, "Manifest.toml"))
pkg"add BSplineKit"
pkg"add MakieCore#sd/beta-20 Makie#sd/beta-20 GLMakie#sd/beta-20 WGLMakie#sd/beta-20 AlgebraOfGraphics#sd/beta-0.20 TopoPlots#sd/beta-20 https://github.com/SimonDanisch/UnfoldMakie.jl#patch-1"
pkg"add Unfold UnfoldSim JSServe Colors DataFrames DataFramesMeta StatsModels StatsBase"
pkg"precompile"
=#



