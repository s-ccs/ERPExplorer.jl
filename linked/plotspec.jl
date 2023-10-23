
using Pkg
Pkg.activate(@__DIR__)
#=
using Pkg
# Somehow I need to redo the project if I want to update the branches
rm(joinpath(@__DIR__, "Project.toml"))
rm(joinpath(@__DIR__, "Manifest.toml"))
pkg"add BSplineKit MixedModels"
pkg"add JSServe#sd/fixes Unfold UnfoldSim Colors DataFrames DataFramesMeta StatsModels StatsBase"
pkg"add MakieCore#sd/blockspec Makie#sd/blockspec WGLMakie#sd/blockspec AlgebraOfGraphics#sd/beta-0.20 TopoPlots#sd/beta-20 https://github.com/SimonDanisch/UnfoldMakie.jl#patch-1"
pkg"precompile"
=#

using BSplineKit
using Unfold
using UnfoldMakie
using UnfoldSim
using WGLMakie
using JSServe
using Random
using Colors
using DataFrames
using DataFramesMeta
using StatsModels
using StatsBase
import JSServe.TailwindDashboard as D
import Makie.PlotspecApi as PA

include("widgets.jl")
include("formula_extractor.jl")


function variable_legend(f, name, values::AbstractRange{<:Number}, palettes)
    cmap = palettes[name][:colormap]
    return PA.Colorbar(f, limits=extrema(values), colormap=cmap, label=string(name))
end

function variable_legend(f, name, values::Set, palettes)
    palette = palettes[name]
    marker_color_lookup = palette[:marker_color]
    marker_lookup = palette[:marker]
    conditions = collect(values)
    elements = map(conditions) do c
        return MarkerElement(marker=marker_lookup(c), color=marker_color_lookup[c])
    end
    return PA.Legend(f, elements, conditions)
end


"""
    variable_legends(figure, value_ranges, palettes)

Creates a fitting legend for each variable.
The returned dictioary with legends can be placed into any plot by assigning it to a layout position:
```julia
legends = variable_legends(figure, value_ranges, palettes)
figure[1, 2] = legends[:continous]
```
"""
function variable_legends(figure, value_ranges, palettes)
    legends = map(value_ranges) do (k, v)
        return k => variable_legend(figure, k, v, palettes)
    end
    return Dict(legends)
end

widget_value(w::Vector{<:String}; resolution=1) = w
widget_value(x::Vector; resolution=1) = x[1]:resolution:x[2]

"""
    formular_widgets(model_variables)

Creates widgets to control each variable of a model.
Return values:
* `widget_signal`: a signal that emits a dictionary with the current values of the widgets.
* `formular_widget`: The HTML element that can be displayed to interact with the the widgets
* `value_ranges`: A dictionary with the value ranges of each variable.
"""
function formular_widgets(variables, formular)
    value_ranges = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in value_ranges]
    widget_names = [formular_text("0 ~ 1")]
    for (name, w) in widgets
        push!(widget_names, formular_text("+"), dropdown(name, w))
    end
    formular_widget = D.FlexRow(widget_names...)
    widget_values = map(nw -> nw[2].value, widgets)
    widget_signal = lift(widget_values...; ignore_equal_values=true) do args...
        result = []
        for (i, widget_value) in enumerate(args)
            # map(identity) -> make a vector with concrete element type
            push!(result, widgets[i][1] => map(identity, widget_value))
        end
        return result
    end
    return widget_signal, formular_widget, value_ranges
end


function gen_data()
    d1, evts = UnfoldSim.predef_eeg(noiselevel=25; return_epoched=true)
    dataS = permutedims(repeat(d1, 1, 1, 64), (3, 1, 2))
    dataS = dataS .+ rand(dataS)

    evts = insertcols(evts,
        :continuous2 => rand(nrow(evts)),
        :continuous3 => rand(nrow(evts)),
        :continuous4 => rand(nrow(evts)),
        :continuous5 => rand(nrow(evts)), :condition2 => shuffle(repeat(["string1", "string2"], outer=div(nrow(evts), 2))),
        :condition3 => shuffle(repeat(["cat", "dog"], outer=div(nrow(evts), 2))),
        :condition4 => shuffle(repeat(["orange", "banana"], outer=div(nrow(evts), 2))),
        :condition5 => shuffle(repeat(["black", "white"], outer=div(nrow(evts), 2))))

    return dataS, evts
end


function create_plot(effDict, value_ranges)
    f = PA.Figure()
    for r in 1:length(unique(effDict[!, :condition]))
        for c in 1:length(unique(effDict[!, :condition2]))
            ax = PA.Axis(f[r, c])
            sub = subset(effDict, :condition2 => x -> x .== effDict[!, :condition2][c], :condition => x -> x .== effDict[!, :condition][r])
            PA.lines(ax, Point2f.(sub.time, sub.yhat); color=sub.condition3 .== "cat")
        end
    end
    # TODO, creating legends!
    return f
end

begin
    # Model selection - not sure where that will happen. Via routes? Via another GUI?
    # formulaS = @formula(0 ~ 1 + condition * continuous)
    formulaS = @formula(0 ~ 1 + condition + condition2 + condition3 + condition4)
    # formulaS = @formula(0 ~ 1 + continuous)
    # formulaS = @formula(0 ~ 1 + condition)
    dataS, evts = gen_data()
    times = range(0, length=size(dataS, 2), step=1 ./ 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
end

App() do s
    # TODO, pass formular, or extract it from model?
    # Likely `[Any][1]`` isn't the generic way to do this in any case.
    formular = Unfold.formula(model)
    variables = extract_variables(model)
    widget_signal, widget_dom, value_ranges = formular_widgets(variables, formular)

    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)
    on(s, widget_signal; update=true) do widget_values
        effect_dict = Dict(k => widget_value(wv) for (k, wv) in widget_values)
        eff = effects(effect_dict, model)
        filter!(x-> x.channel==1 , eff)
        effects_signal[] = eff
    end
    obs = lift(create_plot, s, effects_signal, value_ranges)
    fig = Makie.update_fig(Figure(), obs)
    style = Asset(joinpath(@__DIR__, "..", "style.css"))
    return DOM.div(style, JSServe.TailwindCSS, widget_dom, fig)
end |> display
