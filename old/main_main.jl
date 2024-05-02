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

function value_range(args)
    type = args[end-1]
    default_values = args[end]
    if type == :ContinuousTerm
        mini = round(Int, default_values.min)
        maxi = round(Int, default_values.max)
        return mini:maxi
    elseif type == :CategoricalTerm
        return Set(default_values)
    else
        error("No widget for $(args)")
    end
end

function widget(range::AbstractRange{<: Number})
    range_slider = RangeSlider(range; value=Int[minimum(range), maximum(range)])
    range_slider.ticks[] = Dict(
        "mode" => "range",
        "density" => 10
    )
    range_slider.orientation[] = JSServe.WidgetsBase.vertical
    return range_slider
end

function widget(values::Set)
    return SelectSet(collect(values))
end

widget_value(w) = w.value

function widget_value(slider::RangeSlider)
    map(x-> x[1]:x[2], slider.value)
end


function formular_text(content; class="")
    return DOM.div(content; class="p-1 text-lg font-semibold $(class)")
end

function dropdown(name, content)
    return DOM.div(formular_text(name), DOM.div(content; class="dropdown-content"); class="hover:bg-gray-100 dropdown")
end


function style_map(range::AbstractRange{<:Number})
    return identity # continous
end

function style_map(values::Set)
    mpalette = [:circle, :star4, :xcross, :diamond]
    dict = Dict(v=>mpalette[i] for (i, v) in enumerate(values))
    return v-> dict[v]
end

function signal_to_lines(eff, variables, style_lookup, mcolor_lookup)
    points = Point2f[]
    markers = Symbol[]
    mcolor = RGBAf[]
    colors = Float32[]
    all_cond = unique(eff.condition)

    for group in groupby(eff, variables)
        gpoints = Point2f.(group.time, replace(group.yhat, missing => NaN))
        append!(points, gpoints); push!(points, Point2f(NaN))
        N = length(gpoints) + 1
        var = :continuous
        cval = group[1, var]
        append!(colors, fill(style_lookup[var](cval), N))
        var = :condition
        conval = group[1, var]
        append!(markers, fill(style_lookup[var](conval), N))
        append!(mcolor, fill(mcolor_lookup[conval], N))
    end
    return points, colors, mcolor, markers
end


App() do
    formulaS6 = @formula(0 ~ 1 + condition + continuous)
    m = Unfold.fit(UnfoldModel, formulaS6, evts, dataS, times)
    d = formula_extractor(m)

    dnames = vcat(StatsModels.termvars.(first(values(design(m)))[1].rhs)...)
    value_ranges = Dict((k => value_range(v) for (k, v) in d))
    widgets = Dict((k => widget(v) for (k, v) in value_ranges))
    menu = D.FlexCol((widgets[n] for n in dnames)...)
    style_lookup = Dict((k => style_map(v) for (k, v) in value_ranges))
    mcmap = Makie.wong_colors(0.5)
    mcolor_lookup = Dict("face" => mcmap[1], "car" => mcmap[2])
    signal = map((widget_value(widgets[n]) for n in dnames)...; ignore_equal_values=true) do widget_values...
        effectDict = Dict(dnames .=> widget_values)
        eff = effects(effectDict, m)
        return signal_to_lines(filter(x -> x.channel == 1, eff), dnames, style_lookup, mcolor_lookup)
    end
    points = map(first, signal)
    color = map(x -> x[2], signal)
    mcolor = map(x -> x[3], signal)
    cmap = RGBAf.(Colors.color.(to_colormap(:lighttest)), 0.5)
    f, ax, pl = lines(points, color=color, colormap=cmap, linewidth=2)

    scatter!(ax, points, marker=map(last, signal), markersize=15, color=mcolor)
    widget_names = [formular_text("0 ~ 1")]
    Colorbar(f[1, 2], limits=extrema(value_ranges[:continuous]), colormap=cmap, label="continuous")
    conditions = collect(value_ranges[:condition])
    elements = map(conditions) do c
        MarkerElement(marker=style_lookup[:condition](c), color=mcolor_lookup[c])
    end
    Legend(f[1, 3], elements, conditions)
    for name in dnames
        push!(widget_names, formular_text("+"), dropdown(name, widgets[name]))
    end
    return DOM.div(Asset("style.css"), D.FlexCol(D.FlexRow(widget_names...), f))
end |> display
