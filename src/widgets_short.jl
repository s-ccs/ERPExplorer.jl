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

function Bonito.jsrender(s::Bonito.Session, selector::SelectSet)
    rows = map(selector.items[]) do value
        is_selected = value in selector.value[]
        checkbox = Bonito.Checkbox(is_selected; class = "p-1 m-1")
        on(s, checkbox.value) do checked
            values = copy(selector.value[])
            has_item = value in values
            if checked
                !has_item && push!(values, value)
            else
                has_item && filter!(x -> x != value, values)
            end
            selector.value[] = values
        end
        return Row(string(value), checkbox; align_items = "center")
    end
    return Bonito.jsrender(s, Card(Col(rows...)))
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
    return SelectSet(sort!(collect(values)))
end

function widget(range::AbstractRange{<:Number})
    range_slider = RangeSlider(range; value = Any[minimum(range), maximum(range)])

    range_slider.ticks[] = Dict("mode" => "range", "density" => 10)
    range_slider.orientation[] = Bonito.WidgetsBase.vertical
    return range_slider
end

widget_value(w::Vector{<:String}; resolution = 1) = w
function widget_value(x::Vector{Any}; resolution = 1)
    if isempty(x)
        return x
    end
    if all(v -> v isa AbstractString, x)
        return String.(x)
    end
    return x[1] ≈ x[end] ? (x[1], x[end] - 1e-10) :
           range(Float64(x[1]), Float64(x[end]), length = 5)
end
widget_value(x::Vector; resolution = 1) =
    x[1] ≈ x[end] ? (x[1], x[end] - 1e-10) :
    range(Float64(x[1]), Float64(x[end]), length = 5)


function formular_text(content; class = "")
    return DOM.div(content; class = "px-1 text-lg m-1 font-semibold $(class)")
end
