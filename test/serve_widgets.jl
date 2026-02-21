#!/usr/bin/env julia
import Pkg

const ERP_PATH = "/home/svennaber/Documents/SSCS_vis/ERPExplorer.jl"
const HOST = "127.0.0.1"
const PORT = 8082
const SFREQ = 100

# Use a persistent environment next to this script
const ENV_DIR = joinpath(@__DIR__, ".erp_env")
Pkg.activate(ENV_DIR)
Pkg.develop(url="https://github.com/MakieOrg/AlgebraOfGraphics.jl")
Pkg.develop(path=ERP_PATH)

Pkg.add([
    "Unfold",
    "UnfoldSim",
    "DataFrames",
    "Random",
    "GeometryBasics",
    "TopoPlots",
    "Bonito",
    "WGLMakie",
    "Makie",
])
Pkg.instantiate()

using Random, DataFrames
using GeometryBasics
using Unfold, UnfoldSim
using Makie, WGLMakie
using Bonito
using TopoPlots
using ERPExplorer

# --- your generator (unchanged) ---
function gen_data(n_channels = 64)
    d1, evts = UnfoldSim.predef_eeg(n_repeats = 120, noiselevel = 25; return_epoched = true)
    n_timepoints = size(d1, 1)

    dataS = [
        d1 .+
        3 * sin.(0.1 * pi * i .+ rand() * 2π) .+
        2 * sin.(0.3 * pi * i .* (1:n_timepoints)) .+
        randn(size(d1)) .* 5 .+
        circshift(d1, rand(-10:10)) .* 0.2
        for i = 1:n_channels
    ]
    dataS = permutedims(cat(dataS..., dims = 3), (3, 1, 2))
    dataS = dataS .+ rand(dataS)

    evts = insertcols(
        evts,
        :saccade_amplitude => rand(nrow(evts)) .* 15,
        :luminance => rand(nrow(evts)) .* 100,
        :contrast => rand(nrow(evts)),
        :string => shuffle(
            repeat(
                ["stringsuperlong", "stringshort", "stringUPPERCASE", "stringEXCITED!!!!"],
                outer = div(nrow(evts), 4),
            ),
        ),
        :animal => shuffle(repeat(["cat", "dog"], outer = div(nrow(evts), 2))),
        :fruit => shuffle(repeat(["orange", "banana"], outer = div(nrow(evts), 2))),
        :color => shuffle(repeat(["black", "white"], outer = div(nrow(evts), 2))),
    )

    positions = rand(Point2f, size(dataS, 1))
    return dataS, evts, positions
end

# --- simulate + fit ---
dataS, evts, _positions = gen_data()
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)

# Times length must match the 2nd last dimension of dataS
times = range(0, length = size(dataS, 2), step = 1 / SFREQ)

model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
_, topo_example_positions = TopoPlots.example_data()
half_positions = topo_example_positions[1:2:end]
positions_sets = Dict(
    "TopoPlots example" => topo_example_positions,
    "TopoPlots example (half)" => half_positions,
)

# --- build the full explorer (ERPExplorer already returns a Bonito.App) ---
WGLMakie.activate!()
explorer_app = ERPExplorer.explore(model; positions = positions_sets)

# --- serve it (serve the explorer_app directly; don't wrap it) ---
function start_server(app; host = HOST, port = PORT)
    if isdefined(Bonito, :Server)
        server = Bonito.Server(app, host, port)
        println("Open: http://$(host):$(port)")
        return server
    elseif isdefined(Bonito, :serve)
        url = Bonito.serve(app; host = host, port = port)
        println("Open: ", url)
        return nothing
    else
        error("No Bonito.Server or Bonito.serve found in this Bonito version.")
    end
end

server = start_server(explorer_app)

println("Press Ctrl+C to stop.")
wait(Condition())
