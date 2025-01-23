struct SelectSet
    items::Observable{Vector{Any}}
    value::Observable{Vector{Any}}
end

function SelectSet(items)
    return SelectSet(
        Base.convert(Observable{Vector{Any}}, items),
        Base.convert(Observable{Vector{Any}}, items),
    )
end

function value_range(args)
    type = args[end-1]
    default_values = args[end]
    if (type == :ContinuousTerm) || (type == :BSplineTerm)
        mini = round(Int, default_values.min)
        maxi = round(Int, default_values.max)
        return range(mini, maxi, length = 5)
    elseif type == :CategoricalTerm
        return Set(default_values)
    else
        error("No widget for $(args)")
    end
end

function dropdown(name, content)
    return DOM.div(
        formular_text(name),
        DOM.div(content; class = "dropdown-content");
        class = " bg-slate-100 hover:bg-lime-100 dropdown",
    )
end

function widget(values::Set)
    return SelectSet(collect(values))
end

function widget(range::AbstractRange{<:Number})
    range_slider = RangeSlider(range; value = Any[minimum(range), maximum(range)])

    range_slider.ticks[] = Dict("mode" => "range", "density" => 10)
    range_slider.orientation[] = Bonito.WidgetsBase.vertical
    return range_slider
end

function formular_text(content; class = "")
    return DOM.div(content; class = "px-1 text-lg m-1 font-semibold $(class)")
end
