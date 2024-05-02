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



function explore(model::UnfoldModel; size=(500, 500))
    App() do
        #formular = Unfold.formula(model)
        variables = extract_variables(model)
        widget_checkbox,widget_signal, widget_dom, value_ranges = formular_widgets(variables)

        var_types = map(x -> x[2][3], variables)
        varnames = first.(variables)

        mapping,mapping_dom = mapping_widget(varnames,var_types)
        
        @debug "mapping" mapping
        #mapping = Observable(Dict(:color => :color, :fruit => :marker))
        eff_signal = effects_signal(model, widget_signal)
        on(mapping) do m
            ws = widget_signal.val
            ks_m = keys(m)
            ks_ws = [w.first for w in ws]
            dif = setdiff(ks_ws,ks_m)
            @debug "mapping update" ks_ws ks_m dif
            for k = ks_ws
                @debug k
                widget_checkbox[k][] =  k ∈ ks_m
            end
            
            @debug widget_checkbox
            
        end
        obs = Observable(S.GridLayout())
        l = Base.ReentrantLock()
        Makie.on_latest(eff_signal; update=true) do eff # update = true means only, that it is run once immediately
            lock(l) do
                #var_types = map(x -> x[2][3], variables)
                obs[] = plot_data(eff, value_ranges, varnames[var_types.==:CategoricalTerm], varnames[var_types.==:ContinuousTerm],mapping)
            end
            return
        end
        css = Asset(joinpath(@__DIR__, "..", "style.css"))
        fig = plot(obs; figure=(size=size,))
        return DOM.div(css, Bonito.TailwindCSS, Row(widget_dom,mapping_dom), fig)
    end
end
export explore

end