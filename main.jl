using Pkg
Pkg.activate(".")

using Unfold
using UnfoldSim
using DataFrames
# using ColorSchemes
using Random
using Colors
using DataFramesMeta
using StatsModels
using WGLMakie

include("formula_extractor.jl")

# data simulation

d1, evts = UnfoldSim.predef_eeg(; return_epoched=true);
dataS = permutedims(repeat(d1, 1, 1, 64), (3, 1, 2));
dataS = dataS .+ rand(dataS)
times = range(0, length=size(dataS, 2), step=1 ./ 100)


evts = insertcols(evts,
    :continuous2 => rand(nrow(evts)),
    :continuous3 => rand(nrow(evts)),
    :continuous4 => rand(nrow(evts)),
    :continuous5 => rand(nrow(evts)),

    :condition2 => shuffle(repeat(["string1", "string2"], outer = div(nrow(evts), 2))),
    :condition3 => shuffle(repeat(["cat", "dog"], outer = div(nrow(evts), 2))),
    :condition4 => shuffle(repeat(["orange", "banana"], outer = div(nrow(evts), 2))),
    :condition5 => shuffle(repeat(["black", "white"], outer = div(nrow(evts), 2))))

# model specification

formulaS6 = @formula(0 ~ 1 + condition + continuous)



## This is what JSServe should change for the unchecked terms.
## When the user unselects/deactivates a term, you should return the average value (for now).

using JSServe
import JSServe.TailwindDashboard as D

struct SelectSet
    items::Observable{Vector{Any}}
    value::Observable{Vector{Any}}
end

function SelectSet(items)
    return SelectSet(Base.convert(Observable{Vector{Any}}, items), Base.convert(Observable{Vector{Any}}, items))
end

function JSServe.jsrender(s::Session, selector::SelectSet)
    rows = map(selector.items[]) do value
        c = JSServe.Checkbox(true; class="p-1 m-1")
        on(s, c.value) do x
            values = selector.value[]
            has_item = (value in values)
            if x
                !has_item && push!(values, value)
            else
                has_item && filter!(x -> x != value, values)
            end
            notify(selector.value)
        end
        return D.FlexRow(value, c)
    end
    return JSServe.jsrender(s, D.Card(D.FlexCol(rows...)))
end

function widget(args)
    type = args[end-1]
    default_values = args[end]
    if type == :ContinuousTerm
        mini = round(Int, default_values.min)
        maxi = round(Int, default_values.max)
        range_slider = RangeSlider(mini:maxi; value=Int[mini, maxi])
        range_slider.ticks[] = Dict(
            "mode" => "range",
            "density" => 10
        )
        range_slider.orientation[] = JSServe.WidgetsBase.vertical
        return range_slider
    elseif type == :CategoricalTerm
        return SelectSet(default_values)
    else
        error("No widget for $(args)")
    end
end

widget_value(w) = w.value

function widget_value(slider::RangeSlider)
    map(x-> x[1]:x[2], slider.value)
end

function signal_to_lines(eff, variables)
    points = Point2f[]
    colors = RGBAf[]
    for var in variables
        for k in unique(eff[!, var])
            ix = eff[!, var] .== k
            k_points = Point2f.(eff.time[ix], disallowmissing(eff.yhat[ix]))
            append!(points, k_points)
            push!(points, Point2f(NaN))
            append!(colors, fill(rand(RGBAf), length(k_points) + 1))
        end
    end
    return points, colors
end

function formular_text(content; class="")
    return DOM.div(content; class="p-1 text-lg font-semibold $(class)")
end

function dropdown(name, content)
    return DOM.div(formular_text(name), DOM.div(content; class="dropdown-content"); class="hover:bg-gray-100 dropdown")
end

App() do
    formulaS6 = @formula(0 ~ 1 + condition + continuous)
    m = Unfold.fit(UnfoldModel, formulaS6, evts, dataS, times)
    d = formula_extractor(m)
    dnames = vcat(StatsModels.termvars.(first(values(design(m)))[1].rhs)...)
    widgets = Dict(map(((k, v),) -> k => widget(v), collect(d)))
    menu = D.FlexCol((widgets[n] for n in dnames)...)
    signal = map((widget_value(widgets[n]) for n in dnames)...; ignore_equal_values=true) do widget_values...
        effectDict = Dict(dnames .=> widget_values)
        return signal_to_lines(effects(effectDict, m), dnames)
    end
    f, ax, pl = lines(map(first, signal), color=map(last, signal))
    widget_names = [formular_text("0 ~ 1")]
    for name in dnames
        push!(widget_names, formular_text("+"), dropdown(name, widgets[name]))
    end
    return DOM.div(Asset("style.css"), D.FlexCol(D.FlexRow(widget_names...), f))
end |> display
