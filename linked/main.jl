
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

include("widgets.jl")
include("formula_extractor.jl")

"""
    signal_to_lines(effects, variables, palette)

Creates the styled line plot for the effects.
Will be much easier to implement with:
https://github.com/MakieOrg/Makie.jl/pull/2868
"""
function signal_to_lines(eff, variables, palette)
    points = Point2f[]
    markers = Symbol[]
    mcolor = RGBAf[]
    colors = Float32[]
    for group in groupby(eff, first.(variables))
        gpoints = Point2f.(group.time, replace(group.yhat, missing => NaN))
        append!(points, gpoints)
        push!(points, Point2f(NaN))
        N = length(gpoints) + 1
        for (varname, types) in variables
            if types[3] == :CategoricalTerm
                conval = group[1, varname]
                p = palette[varname]
                append!(markers, fill(p[:marker](conval), N))
                append!(mcolor, fill(p[:marker_color][conval], N))
            else
                cval = group[1, varname]
                append!(colors, fill(palette[varname][:color](cval), N))
            end
        end
    end
    return points, colors, mcolor, markers
end


function variable_legend(f, name, values::AbstractRange{<:Number}, palettes)
    cmap = palettes[name][:colormap]
    return Colorbar(f, limits=extrema(values), colormap=cmap, label=string(name))
end

function variable_legend(f, name, values::Set, palettes)
    palette = palettes[name]
    marker_color_lookup = palette[:marker_color]
    marker_lookup = palette[:marker]
    conditions = collect(values)
    elements = map(conditions) do c
        return MarkerElement(marker=marker_lookup(c), color=marker_color_lookup[c])
    end
    return Legend(f, elements, conditions)
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

widget_value(w::Vector{<: String}; resolution=1) = w
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


function effects_plot(model)
    # TODO, pass formular, or extract it from model?
    # Likely `[Any][1]`` isn't the generic way to do this in any case.
    formular = Unfold.formula(model)
    variables = extract_variables(model)
    widget_signal, widget_dom, value_ranges = formular_widgets(variables, formular)

    # TODO: make this more easily stylable, with clearer mappings from variables to styles
    palettes = Dict(k => style_map(v) for (k, v) in value_ranges)

    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)
    effects_highres_signal = Observable{Any}(nothing; ignore_equal_values=true)

    on(widget_signal; update=true) do widget_values
        effect_dict = Dict(k => widget_value(wv) for (k, wv) in widget_values)
        effects_dict_highres = Dict(k => widget_value(wv; resolution=0.1) for (k, wv) in widget_values)
        effects_signal[] = effects(effect_dict, model)
        # TODO, this seems very expensive, how can we just call `effects` one time?
        effects_highres_signal[] = @time effects(effects_dict_highres, model)
    end

    line_signal = lift(effects_signal) do eff
        # TODO, use Observable{Plot} from https://github.com/MakieOrg/Makie.jl/pull/2868
        # Would also be nice to turn this into a recipe?
        return signal_to_lines(filter(x -> x.channel == 1, eff), variables, palettes)
    end

    points = lift(first, line_signal)
    color = lift(x -> x[2], line_signal)
    mcolor = lift(x -> x[3], line_signal)
    cvar = filter(x-> x[2][3] == :ContinuousTerm, variables)
    f = Figure()
    ax = Axis(f[1, 1])
    if !isempty(cvar)
        cmap = palettes[first(cvar)[1]][:colormap]
        lines!(ax, points, color=color, colormap=cmap, linewidth=2, highclip=:red, lowclip=:blue)
    end
    marker = lift(last, line_signal)
    @show length(points[]) @show length(mcolor[]) typeof(mcolor[]) typeof(marker[]) length(marker[])
    scatter!(ax, points, marker=marker, markersize=5, color=mcolor)
    ax.xrectzoom = false
    ax.yrectzoom = false

    selrect = rectselect(ax)

    yhat_points = Observable(Point2f[]; ignore_equal_values=true)
    yhat_colors = Observable(RGBAf[]; ignore_equal_values=true)
    mcolor_lookup = palettes[:condition][:marker_color]

    onany(selrect, effects_highres_signal) do slider, eff_highres
        sl_ori = slider.origin[1]
        sl_end = slider.origin[1] + slider.widths[1]
        sub = subset(eff_highres, :time => (t -> (t .> sl_ori) .&& (t .<= sl_end)); view=true)
        yhat = @by(sub, Not([:time, :yhat, :channel]), :yhat = mean(:yhat))
        yhat_points[] = Point2f.(yhat.continuous, yhat.yhat)
        yhat_colors[] = getindex.(Ref(mcolor_lookup), yhat.condition)
        return yhat
    end

    ax2, pl = scatter(f[2, 1], yhat_points, color=yhat_colors)
    ylims!(ax2, [40, 60])
    on(yhat_points) do _
        autolimits!(ax2)
    end
    ax2.xlabel = ":continuous"
    ax2.ylabel = L"[$\mu V$]"
    ax.ylabel = L"[$\mu V$]"

    legends = variable_legends(f, value_ranges, palettes)
    legend_slot = f[1, 2]
    for (i, legend) in enumerate(values(legends))
        legend_slot[1, i] = legend
    end

    return DOM.div(Asset("style.css"), JSServe.TailwindCSS, D.FlexCol(widget_dom, f))
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


begin
    # Model selection - not sure where that will happen. Via routes? Via another GUI?
    # formulaS = @formula(0 ~ 1 + condition * continuous)
    formulaS = @formula(0 ~ 1 + condition + condition3 + condition4)
    # formulaS = @formula(0 ~ 1 + continuous)
    # formulaS = @formula(0 ~ 1 + condition)
    dataS, evts = gen_data()
    times = range(0, length=size(dataS, 2), step=1 ./ 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

    App(s-> effects_plot(model))
end

import Makie.PlotSpecApi as P

function create_plot(effDict)
    f = P.Figure()
    for r = 1:length(effDict[:condition])
        for c = 1:length(effDict[:condition2])
            ax = P.Axis(f[r, c])
            sub = subset(effects_signal, :condition2 => x -> x .== effDict[:condition2][c], :condition => x -> x .== effDict[:condition][r])
            P.lines(ax, sub.time, sub.yhat; color=sub.condition3 .== "cat", linestyle=sub.condition4)
        end
    end
    retif
end

begin

    formulaS6 = @formula(0 ~ 1 + condition + condition2 + condition3+condition4)
    dataS, evts = gen_data()
    times = range(0, length=size(dataS, 2), step=1 ./ 100)
    model = Unfold.fit(UnfoldModel, formulaS6, evts, dataS, times)
    ev = extract_variables(model)
    effDict =  Dict([e[1] => e[2][4] for e in ev])
    effects_signal = effects(effDict, model)

    f = P.Figure()
    for r = 1:length(effDict[:condition])
        for c = 1:length(effDict[:condition2])
            ax = P.Axis(f[r, c])
            sub = subset(effects_signal, :condition2 => x->x.== effDict[:condition2][c], :condition => x -> x.== effDict[:condition][r])
            P.lines(ax,sub.time,sub.yhat;color=sub.condition3.=="cat",linestyle=sub.condition4)
        end
    end
    f
end
