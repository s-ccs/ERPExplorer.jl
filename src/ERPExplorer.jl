module ERPExplorer

using Unfold
#import Bonito.TailwindDashboard as D
import Makie.SpecApi as S

using BSplineKit
using Unfold
using UnfoldMakie
using WGLMakie
using Bonito
using Random
using Colors
using DataFrames
using DataFramesMeta
using StatsModels
using StatsBase
using TopoPlots

include("formula_extractor.jl")
include("functions.jl")
include("widgets.jl")
include("plot_data.jl")

function explore(model::UnfoldModel; positions = nothing, size = (700, 600))
    App() do
        variables = extract_variables(model)
        widget_checkbox, widget_signal, widget_dom, value_ranges =
            formular_widgets(variables)

        var_types = map(x -> x[2][3], variables)
        varnames = first.(variables)

        mapping, mapping_dom = mapping_dropdowns(varnames, var_types)

        if isnothing(positions)
            channel = Observable(1)
            topo_widget = nothing
        else
            topo_widget, channel = topoplot_widget(positions; size = size .* 0.5)
        end
        #@debug "mapping" mapping
        #mapping = Observable(Dict(:color => :color, :fruit => :marker))
        eff_signal = effects_signal(model, widget_signal, channel)
        on(mapping) do m
            ws = widget_signal.val
            ks_m = values(m)
            ks_ws = [w.first for w in ws]
            for k in ks_ws
                widget_checkbox[k][] = k ∈ ks_m
            end
        end
        obs = Observable(S.GridLayout())
        l = Base.ReentrantLock()
        Makie.onany_latest(eff_signal, mapping; update = true) do eff, mapping # update = true means only, that it is run once immediately
            lock(l) do
                #var_types = map(x -> x[2][3], variables)
                obs[] = plot_data(
                    eff,
                    value_ranges,
                    varnames[var_types.==:CategoricalTerm],
                    varnames[var_types.==:ContinuousTerm],
                    mapping,
                )
            end
            return
        end
        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(obs; figure = (size = size,))
        return DOM.div(
            css,
            Bonito.TailwindCSS,
            Grid(
                Card(widget_dom, style = Styles("grid-area" => "header")),
                Card(mapping_dom, style = Styles("grid-area" => "sidebar")),
                Card(topo_widget, style = Styles("grid-area" => "topo")),
                Card(fig, style = Styles("grid-area" => "content"));
                columns = "5fr 1fr",
                rows = "1fr 6fr 4fr",
                areas = """
'header header'
'content sidebar'
'content topo'
""",
            );
            style = Styles(
                "height" => "$(1.2*size[2])px",
                "width" => "$(size[1])px",
                "margin" => "20px",
                "position" => :relative,
            ),
        )
    end
end
export explore

end
