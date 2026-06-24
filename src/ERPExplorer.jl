module ERPExplorer

import Makie.SpecApi as S

using AlgebraOfGraphics
using Unfold
using WGLMakie
using Bonito
using Colors
using DataFrames
using StatsModels
using TopoPlots

include("explore.jl")
include("functions_preprocessing.jl")
include("functions_formular.jl")
include("functions_plotting.jl")
include("widgets_short.jl")
include("widgets_long.jl")

end
