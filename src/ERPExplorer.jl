module ERPExplorer

using Unfold
import Bonito.TailwindDashboard as D
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



function explore(model::UnfoldModel)
    App() do
        formular = Unfold.formula(model)
        variables = extract_variables(model)
        widget_signal, widget_dom, value_ranges = formular_widgets(variables, formular)

        eff_signal = effects_signal(model, widget_signal)
        varnames = first.(variables)
        var_types = map(x -> x[2][3], variables)
        obs = Observable(S.GridLayout())
        l = Base.ReentrantLock()
        Makie.on_latest(eff_signal; update=true) do eff
            lock(l) do
                var_types = map(x -> x[2][3], variables)
                obs[] = plot_data(eff, value_ranges, varnames[var_types.==:CategoricalTerm], varnames[var_types.==:ContinuousTerm])
            end
            return
        end
        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(obs; figure=(size=(500, 500),))
        return DOM.div(css, Bonito.TailwindCSS, widget_dom, fig)
    end
end
export explore

end