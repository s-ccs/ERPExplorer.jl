begin
    using Pkg
    Pkg.activate(".")
    Pkg.status()
    using Revise
    using ERPExplorer
    using UnfoldSim
    using DataFrames
    using Random
    using Unfold
    using Bonito
end

include("gen_data.jl")
#formulaS = @formula(0 ~ 1 +luminance + contrast + saccade_amplitude + string + animal + fruit + color)
formulaS = @formula(0 ~ 1 + animal + fruit)
formulaS = @formula(0 ~ 1 + luminance + fruit + animal)
dataS, evts = gen_data()
times = range(0, length = size(dataS, 2), step = 1 ./ 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

explore(model)

#---

a = Bonito.App() do
    #formular = Unfold.formula(model)
    variables = ERPExplorer.extract_variables(model)
    widget_signal, widget_dom, value_ranges = ERPExplorer.formular_widgets(variables)
    onany(widget_signal, value_ranges) do ws, vs
        @show ws, vs
    end
    css = ERPExplorer.Asset(joinpath(@__DIR__, "..", "style.css"))
    return ERPExplorer.DOM.div(css, ERPExplorer.Bonito.TailwindCSS, widget_dom)
end
