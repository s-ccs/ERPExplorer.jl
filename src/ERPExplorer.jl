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



include("formula_extractor.jl")
include("functions.jl")
include("widgets.jl")



function explore(model::UnfoldModel; size = (500, 500))
    App() do
        #formular = Unfold.formula(model)
        variables = extract_variables(model)
        widget_checkbox, widget_signal, widget_dom, value_ranges =
            formular_widgets(variables)

        var_types = map(x -> x[2][3], variables)
        varnames = first.(variables)

        mapping, mapping_dom = mapping_widget(varnames, var_types)

        #@debug "mapping" mapping
        #mapping = Observable(Dict(:color => :color, :fruit => :marker))
        eff_signal = effects_signal(model, widget_signal)
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
        Makie.on_latest(eff_signal; update = true) do eff # update = true means only, that it is run once immediately
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
            Grid(
                Card(widget_dom, style = Styles("grid-area" => "header")),
                Card(mapping_dom, style = Styles("grid-area" => "sidebar")),
                Card(fig, style = Styles("grid-area" => "content"));
                columns = "5fr 1fr",
                rows = "1fr 5fr",
                areas = """
'header header'
'content sidebar'
""",
            );
            style = Styles(
                "height" => "800px",
                "margin" => "20px",
                "position" => :relative,
            ),
        )
    end
end
export explore

end
