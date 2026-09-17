module ERPExplorer

import Makie.SpecApi as S

using AlgebraOfGraphics
using Unfold
using WGLMakie
using Bonito
using Colors
using CSV
using DataFrames
using JLD2
using StatsModels
using TopoPlots
using UnfoldMakie

include("explore.jl")
include("dashboard.jl")
include("functions_loading.jl")
include("functions_preprocessing.jl")
include("functions_formular.jl")
include("functions_plotting.jl")
include("widgets_short.jl")
include("widgets_long.jl")

end
