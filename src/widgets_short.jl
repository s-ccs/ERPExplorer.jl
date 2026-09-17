struct SelectSet
    items::Observable{Vector{Any}}
    value::Observable{Vector{Any}}
end

struct SignificantRangeSlider{T<:AbstractRange,ET<:AbstractArray} <:
       Bonito.WidgetsBase.AbstractWidget{T}
    range::Observable{T}
    value::Observable{ET}
    connect::Observable{Bool}
    orientation::Observable{Any}
    tooltips::Observable{Bool}
    ticks::Observable{Dict{String,Any}}
    digits::Observable{Int}
end

function SignificantRangeSlider(range::T; value = Any[first(range)], digits = 3) where {T<:AbstractRange}
    return SignificantRangeSlider{T,typeof(value)}(
        Observable(range),
        Observable(value),
        Observable(true),
        Observable(Bonito.WidgetsBase.horizontal),
        Observable(false),
        Observable(Dict{String,Any}()),
        Observable(digits),
    )
end

const significant_noUiSlider = Bonito.ES6Module(Bonito.dependency_path("nouislider.min.js"))
const significant_noUiSliderCSS = Bonito.Asset(Bonito.dependency_path("noUISlider.css"))

function Bonito.jsrender(session::Bonito.Session, slider::SignificantRangeSlider)
    # Register before session HTML is assembled, including Pluto's inline assets.
    Bonito.jsrender(session, significant_noUiSlider)
    args = (
        slider.range,
        slider.connect,
        slider.orientation,
        slider.tooltips,
        slider.ticks,
        slider.digits,
    )
    style = map(session, args...) do range, connect, orientation, tooltips, ticks, digits
        value = slider.value[]
        return Dict(
            "range" => Dict("min" => range[1], "max" => range[end]),
            "step" => step(range),
            "start" => Any[value...],
            "connect" => connect,
            "tooltips" => tooltips,
            "direction" => "ltr",
            "orientation" => string(orientation),
            "pips" => isempty(ticks) ? nothing : ticks,
            "format_digits" => digits,
        )
    end
    rangediv = DOM.div(; class = "erp-range-slider", var"data-testid" = "continuous-slider", style = "height: 160px; width: 12px; margin: 20px 36px;")

    slider_helpers = js"""
    function significant_formatter(digits){
        function trim(text){
            if (text.indexOf("e") >= 0) {
                const parts = text.split("e");
                let mantissa = parts[0];
                while (mantissa.indexOf(".") >= 0 && mantissa.endsWith("0")) {
                    mantissa = mantissa.slice(0, -1);
                }
                if (mantissa.endsWith(".")) {
                    mantissa = mantissa.slice(0, -1);
                }
                return mantissa + "e" + parts[1];
            }
            while (text.indexOf(".") >= 0 && text.endsWith("0")) {
                text = text.slice(0, -1);
            }
            if (text.endsWith(".")) {
                text = text.slice(0, -1);
            }
            return text;
        }
        return {
            to: function(value){
                const number = Number(value);
                if (!Number.isFinite(number)) {
                    return String(value);
                }
                if (number === 0) {
                    return "0";
                }
                const abs_value = Math.abs(number);
                const sig_digits = Math.max(1, Number(digits) || 3);
                if (abs_value >= 1e4 || abs_value < 1e-3) {
                    return trim(number.toExponential(sig_digits - 1));
                }
                return trim(number.toPrecision(sig_digits));
            },
            from: function(value){
                return Number(value);
            }
        };
    }
    function apply_significant_format(style){
        // Show enough digits to distinguish adjacent slider steps.
        const magnitude = Math.max(Math.abs(style.range.min), Math.abs(style.range.max));
        const needed = magnitude > 0 && style.step > 0
            ? Math.ceil(Math.log10(magnitude / style.step)) + 1 : 3;
        const formatter = significant_formatter(Math.min(17, Math.max(style.format_digits, needed)));
        delete style.format_digits;
        style.format = {to: String, from: Number};
        style.tooltips = style.tooltips ? [formatter, formatter] : false;
        if (style.pips) {
            style.pips.format = formatter;
        }
        return style;
    }
    """

    create_slider = js"""
    function create_slider(style){
        $(slider_helpers)
        const range = $(rangediv);
        range.noUiSlider.updateOptions(apply_significant_format(style), true);
    }"""
    on_range = js"""function onload(range){
        $(slider_helpers)
        const style = apply_significant_format($(style[]));
        $(significant_noUiSlider).then(NUS=> {
            NUS.create(range, style);
            range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
                $(slider.value).notify(Array.from(unencoded, Number));
            });
        })
    }"""
    Bonito.onload(session, rangediv, on_range)
    onjs(session, style, create_slider)
    return DOM.div(Bonito.jsrender(session, significant_noUiSliderCSS), rangediv;
        class = "erp-slider-container")
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
        checkbox = Bonito.Checkbox(is_selected; style = Styles("padding" => "4px", "margin" => "4px"))
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
        mini, maxi = normalize_continuous_bounds(default_values.min, default_values.max)
        return continuous_slider_range(mini, maxi)
    elseif type == :CategoricalTerm
        return Set(default_values)
    else
        error("No widget for $(args)")
    end
end

function normalize_continuous_bounds(minimum_value, maximum_value)
    mini = Float64(minimum_value)
    maxi = Float64(maximum_value)
    if mini > maxi
        mini, maxi = maxi, mini
    end
    isfinite(mini) && isfinite(maxi) || throw(ArgumentError("Slider bounds must be finite."))
    if mini == maxi
        delta = max(abs(mini), 1.0) * 1e-6
        mini -= delta
        maxi += delta
    end
    return mini, maxi
end

function continuous_slider_range(mini, maxi; steps = 101)
    steps >= 2 || throw(ArgumentError("steps must be at least 2"))
    mini, maxi = normalize_continuous_bounds(mini, maxi)
    return range(mini, maxi, length = steps)
end

function dropdown(name, content)
    return DOM.div(
        formular_text(name),
        DOM.div(content; class = "erp-dropdown-content");
        class = "erp-dropdown", tabindex = 0,
    )
end

function widget(values::Set)
    return SelectSet(sort_values(values))
end

function widget(range::AbstractRange{<:Number})
    range_slider = SignificantRangeSlider(
        range;
        value = Any[minimum(range), maximum(range)],
        digits = 3,
    )

    range_slider.ticks[] = Dict("mode" => "range", "density" => 10)
    range_slider.tooltips[] = true
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
    lo, hi = normalize_continuous_bounds(lo, hi)
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
    return DOM.div(content; class = "erp-formula-term $(class)")
end
