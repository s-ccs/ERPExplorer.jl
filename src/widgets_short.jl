struct SelectSet
    items::Observable{Vector{Any}}
    value::Observable{Vector{Any}}
end

function SelectSet(items)
    items_any = Any[items...]
    return SelectSet(
        Observable{Vector{Any}}(items_any),
        Observable{Vector{Any}}(copy(items_any)),
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
    if is_continuous_like(type)
        mini = Float64(default_values.min)
        maxi = Float64(default_values.max)
        if mini > maxi
            mini, maxi = maxi, mini
        end
        if mini ≈ maxi
            delta = max(abs(mini), 1.0) * 1e-6
            mini -= delta
            maxi += delta
        end
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
    return SelectSet(sort_values(values))
end

function widget(range::AbstractRange{<:Number})
    range_slider = RangeSlider(range; value = Any[minimum(range), maximum(range)])

    range_slider.ticks[] = Dict("mode" => "range", "density" => 10)
    range_slider.orientation[] = Bonito.WidgetsBase.vertical
    return range_slider
end

function sort_values(values)
    items = collect(values)
    try
        return sort!(items)
    catch
        return sort!(items; by = string)
    end
end

function continuous_widget_value(x::AbstractVector)
    if isempty(x)
        return x
    end
    lo = Float64(x[begin])
    hi = Float64(x[end])
    if lo > hi
        lo, hi = hi, lo
    end
    if lo ≈ hi
        delta = max(abs(lo), 1.0) * 1e-6
        lo -= delta
        hi += delta
    end
    return range(lo, hi, length = 5)
end

function widget_value(x::AbstractVector, term_type::Symbol)
    if is_continuous_like(term_type)
        return continuous_widget_value(x)
    elseif term_type == :CategoricalTerm
        return collect(x)
    else
        error("No widget value conversion for term type $(term_type)")
    end
end

widget_value(w::AbstractVector{<:AbstractString}) = collect(w)
widget_value(x::AbstractVector{<:Real}) = continuous_widget_value(x)
widget_value(x::AbstractVector) = collect(x)


function formular_text(content; class = "")
    return DOM.div(content; class = "px-1 text-lg m-1 font-semibold $(class)")
end
