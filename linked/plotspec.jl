using Pkg
Pkg.activate(@__DIR__)
#=
# Somehow I need to redo the project if I want to update the branches
rm(joinpath(@__DIR__, "Project.toml"))
rm(joinpath(@__DIR__, "Manifest.toml"))
pkg"add BSplineKit"
pkg"add Unfold UnfoldSim JSServe#sd/fixes Colors DataFrames DataFramesMeta StatsModels StatsBase"
pkg"add MakieCore#sd/beta-20 Makie#sd/beta-20 GLMakie#sd/beta-20 WGLMakie#sd/beta-20 AlgebraOfGraphics#sd/beta-0.20 TopoPlots#sd/beta-20 https://github.com/SimonDanisch/UnfoldMakie.jl#patch-1"
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
import Makie.SpecApi as S

include("widgets.jl")
include("formula_extractor.jl")


function variable_legend(f, name, values::AbstractRange{<:Number}, palettes)
    range, cmap = palettes[name][:colormap]
    return S.Colorbar(f, limits=range, colormap=cmap, label=string(name))
end

function variable_legend(f, name, values::Set, palettes)
    palette = palettes[name]
    marker_color_lookup = (x) -> begin
        if haskey(palette, :color)
            return palette[:color][x]
        else
            return :black
        end
    end
    marker_lookup = (x) -> begin
        if haskey(palette, :marker)
            return palette[:marker][x]
        else
            return :rect
        end
    end
    conditions = collect(values)
    elements = map(conditions) do c
        return MarkerElement(marker=marker_lookup(c), color=marker_color_lookup(c))
    end
    return S.Legend(f, elements, conditions)
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

function effects_signal(model, widget_signal)
    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)
    on(widget_signal; update=true) do widget_values
        effect_dict = Dict(k => widget_value(wv) for (k, wv) in widget_values)
        eff = effects(effect_dict, model)
        filter!(x -> x.channel == 1, eff)
        effects_signal[] = eff
    end
    return effects_signal
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


function plot_data(data, value_ranges, categorical_vars, continuous_vars)
    fig = S.Figure()
    mpalette = [:circle, :star4, :xcross, :diamond]
    cpalette = Makie.wong_colors()
    cat_styles = [:color => cpalette, :marker => mpalette]
    cat_values = [unique(data[!, cat]) for cat in categorical_vars]
    scatter_styles = [cat => (style[1] => Dict(zip(vals, style[2]))) for (style, vals, cat) in zip(cat_styles, cat_values, categorical_vars)]

    continous_styles = [:colormap => :viridis, :colormap => :heat]
    continuous_values = [extrema(data[!, con]) for con in continuous_vars]
    line_styles = [cat => (style[1] => (val, style[2])) for (style, val, cat) in zip(continous_styles, continuous_values, continuous_vars)]

    function create_plot!(ax, data, catvars, vars)
        selector = [(name => x -> x .== var) for (name, var) in zip(catvars, vars)]
        sub = subset(data, selector...)
        points = Point2f.(sub.time, sub.yhat)
        args = [kw => vals[val] for (val, (name, (kw, vals))) in zip(vars, scatter_styles)]
        S.scatter!(ax, points; markersize=10, args...)
        line_args = [kw => cmap for (name, (kw, (lims, cmap))) in line_styles]
        line_args2 = [:colorrange => lims for (name, (kw, (lims, cmap))) in line_styles]
        line_args3 = [:color => sub[!, name] for name in continuous_vars]
        S.lines!(ax, points; line_args..., line_args2..., line_args3...)
    end

    gridmax = 1
    legend_entries = []
    if length(categorical_vars) >= 2
        cat1 = categorical_vars[end]
        cat2 = categorical_vars[end-1]
        values1 = cat_values[end]
        values2 = cat_values[end-1]
        gridmax = length(values1)
        append!(legend_entries, value_ranges[1:end-2])
        for (i, catval1) in enumerate(values1)
            for (k, catval2) in enumerate(values2)
                ax = S.Axis(fig[k, i]; title="$cat1: $catval1, $cat2: $catval2")
                subdata = subset(data, cat1 => x -> x .== catval1, cat2 => x -> x .== catval2)
                for vars in Iterators.product(cat_values[1:end-2]...)
                    create_plot!(ax, subdata, categorical_vars[1:end-2], vars)
                end
            end
        end
    else
        append!(legend_entries, value_ranges)
        ax = S.Axis(fig[1, 1])
        for vars in Iterators.product(cat_values...)
            create_plot!(ax, categorical_vars, vars)
        end
    end

    palettes = Dict(map(((k, v),) -> k => Dict(v), vcat(line_styles, scatter_styles)))
    for (i, (k, v)) in enumerate(legend_entries)
        variable_legend(fig[1, gridmax+i], k, v, palettes)
    end
    fig
end


App() do
    formulaS = @formula(0 ~ 1 + condition2 + continuous + condition3 + condition4)
    dataS, evts = gen_data()
    times = range(0, length=size(dataS, 2), step=1 ./ 100)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
    formular = Unfold.formula(model)
    variables = extract_variables(model)
    widget_signal, widget_dom, value_ranges = formular_widgets(variables, formular)
    eff_signal = effects_signal(model, widget_signal)
    varnames = first.(variables)
    var_types = map(x -> x[2][3], variables)
    obs = Observable(S.Figure())
    Makie.on_latest(eff_signal; update=true) do eff
        var_types = map(x -> x[2][3], variables)
        obs[] = plot_data(eff, value_ranges, varnames[var_types.==:CategoricalTerm], varnames[var_types.==:ContinuousTerm])
        return
    end
    css = Asset(joinpath(@__DIR__, "..", "style.css"))
    fig = plot(obs; figure=(size=(1000, 1000),))
    return DOM.div(css, JSServe.TailwindCSS, widget_dom, fig)
end
