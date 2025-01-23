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

widget_value(w::Vector{<:String}; resolution = 1) = w
widget_value(x::Vector; resolution = 1) =
    x[1] ≈ x[end] ? Float64[] : range(Float64(x[1]), Float64(x[end]), length = 5)


function formular_text(content; class = "")
    return DOM.div(content; class = "px-1 text-lg m-1 font-semibold $(class)")
end

function variable_legend(name, values::AbstractRange{<:Number}, palette::Dict)
    range, cmap = palette[:colormap]
    return S.Colorbar(limits = range, colormap = cmap, label = string(name))
end

function variable_legend(name, values::Set, palette::Dict)
    marker_color_lookup = (x) -> begin
        if haskey(palette, :color)
            return get(palette[:color], x, :black)
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
        return MarkerElement(marker = marker_lookup(c), color = marker_color_lookup(c))
    end
    return S.Legend(elements, conditions)
end
