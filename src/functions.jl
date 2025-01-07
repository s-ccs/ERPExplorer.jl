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

widget_value(w::Vector{<:String}; resolution = 1) = w
widget_value(x::Vector; resolution = 1) =
    x[1] ≈ x[end] ? Float64[] : range(Float64(x[1]), Float64(x[end]), length = 5)

"""
    formular_widgets(variables)
Creates widgets to control each variable of a model.\\
Arguments:\\
- variables

**Return Values:**
- `widget_signal`: a signal that emits a dictionary with the current values of the widgets.
- `formular_widget`: The HTML element that can be displayed to interact with the the widgets
- `value_ranges`: A dictionary with the value ranges of each variable.
"""
function formular_widgets(variables)
    value_ranges = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in value_ranges]
    checkboxes = [Bonito.Checkbox(false) for k in value_ranges]
    widget_names = [formular_text("0 ~ 1")]
    for k = 1:length(widgets)
        c = checkboxes[k]
        name = widgets[k].first
        w = widgets[k].second
        push!(widget_names, formular_text("+"), formular_text(c), dropdown(name, w))

    end
    formular_widget = Row(widget_names...)

    widget_values = map(nw -> nw[2].value, widgets)
    checkbox_values = map(c -> c.value, checkboxes)

    widget_signal =
        lift(widget_values..., checkbox_values...; ignore_equal_values = true) do args...
            result = []
            for i = 1:length(args[1:end/2])
                c = args[i+length(args)/2]
                w = args[i]

                push!(result, widgets[i][1] => (map(identity, c), map(identity, w)))
            end
            return result
        end
    return Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables)),
    widget_signal,
    formular_widget,
    value_ranges
end

function effects_signal(model, widget_signal, channel)
    effects_signal = Observable{Any}(nothing; ignore_equal_values = true)

    onany(widget_signal, channel; update = true) do widget_values, chan

        effect_dict = Dict(
            k => widget_value(wv[2]) for (k, wv) in widget_values if !isempty(wv) && wv[1]
        )
        @debug effect_dict
        if isempty(effect_dict)
            effect_dict = Dict(:dummy => ["dummy"])
        end
        eff = effects(effect_dict, model)
        for (k, wv) in widget_values
            if isempty(wv[2]) || !wv[1]
                eff[!, k] .= "typical_value"
            end
        end

        filter!(x -> x.channel == chan, eff)
        effects_signal[] = eff
    end
    return effects_signal
end


"""
    create_plot!(plots, data, vars, scatter_styles, line_styles, continuous_vars)

Arguments:\\
- `plots` - a SpecApi list to push into.\\
- `data` - a DataFrame to be subsetted.\\
- `vars` contains the levels to be plotted.\\

**Return Value:** .
"""
function create_plot!(plots, data, vars, scatter_styles, line_styles, continuous_vars)

    selector = [(name => x -> x .== var) for (name, var) in vars]

    sub = subset(data, selector...)
    @assert !isempty(sub) "this shouldn't be empty..."
    points = Point2f.(sub.time, sub.yhat)
    points[sub.time .≈ maximum(sub.time)] .= Ref(Point2f(NaN)) # terrible hack, it will remove the last point from ploitting. better would be to loop the lines! with views of the dataframe...


    #    @debug "create_plot!" scatter_styles vars
    #args = [kw => vals[val] for (val, (name, (kw, vals))) in zip(vars, scatter_styles)]
    args = [
        scatter_styles[term][1] => scatter_styles[term][2][val] for
        (term, val) in vars if term ∈ keys(scatter_styles)
    ]

    if isempty(line_styles)
        line_args = []
        line_args2 = []
        line_args3 = args

        if !isempty(args) && !any(x -> x[1] .== :color, line_args3)
            push!(args, :color => :black)
        end


    else
        line_args = [kw => cmap for (name, (kw, (lims, cmap))) in line_styles]
        line_args2 = [:colorrange => lims for (name, (kw, (lims, cmap))) in line_styles]
        line_args3 = [:color => sub[!, name] for name in continuous_vars]
    end
    push!(plots, S.Scatter(points; markersize = 10, args...))

    push!(plots, S.Lines(points; line_args..., line_args2..., line_args3...))
    return
end
