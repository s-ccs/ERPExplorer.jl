module ERPExplorer

using Unfold
#import Bonito.TailwindDashboard as D
import Makie.SpecApi as S

using BSplineKit
using Unfold
using WGLMakie
using Bonito
using Random
using Colors
using DataFrames
using DataFramesMeta
using StatsModels
using StatsBase
using TopoPlots

include("explore.jl")
include("functions_preprocessing.jl")
include("functions_formular.jl")
include("functions_plotting.jl")
include("functions_style_scatter_lines.jl")
include("widgets_short.jl")
include("widgets_long.jl")

end
