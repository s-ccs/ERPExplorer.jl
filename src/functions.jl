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
- `variables::Vector{Pair{Symbol}}` - vector of key-value pairs with information about the model formula terms.

Actions:
- Extract ranges of term values.
- Create widgets for each term (`Slider` for continuous, `SelectSet` for categorical).
- Creating the formula with checkboxes and translating to HTML code. 
- Convert checkboxes to Observables. 

**Return Values:**
- `widget_checkbox`: Dictionary with the current values of the widgets (term => values).
- `widget_signal`: widget_checkbox but as Observable, a signal that emits a dictionary with the current values of the widgets.
- `formular_widget`: The HTML element that can be displayed to interact with the the widgets.
- `value_ranges`: A dictionary containing the value ranges of each formula term.
"""
function formular_widgets(variables)
    value_ranges = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in value_ranges]
    checkboxes = [Bonito.Checkbox(false) for k in value_ranges]
    widget_names = [formular_text("0 ~ 1")]

    for k = 1:length(widgets)
        c = checkboxes[k]
        w_cat_term = widgets[k].first
        w_value = widgets[k].second
        push!(
            widget_names,
            formular_text("+"),
            formular_text(c),
            dropdown(w_cat_term, w_value),
        )
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
    widget_checkbox = Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables))

    return widget_checkbox, widget_signal, formular_widget, value_ranges
end

"""
    yhats_signal(model, widget_signal, channel)
Creates a dictionary with yhat values and more.\\

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - vector of key-value pairs with information about the model formula terms.
- `widget_signal::Observable{Vector{Any}}` - a signal that emits a dictionary with the current values of the widgets.
- `channel::Observable{Int64}` - number of selected channel- 

Actions:
- Compute predicted value (yhat) of the given model using `effects`.
- Create `DataFrame` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.
- Make it Observable.

**Return Value:** `yhats_signal::Observable{Any}` containing DataFrame with yhats. 
"""
function yhats_signal(model, widget_signal, channel)

    yhats_signal = Observable{Any}(nothing; ignore_equal_values = true)

    onany(widget_signal, channel; update = true) do widget_values, chan
        yhat_dict = Dict(
            k => widget_value(wv[2]) for (k, wv) in widget_values if !isempty(wv) && wv[1]
        )
        if isempty(yhat_dict)
            yhat_dict = Dict(:dummy => ["dummy"])
        end
        yhats = effects(yhat_dict, model)

        for (k, wv) in widget_values
            if isempty(wv[2]) || !wv[1]
                yhats[!, k] .= "typical_value"
            end
        end

        filter!(x -> x.channel == chan, yhats)
        yhats_signal[] = yhats
    end

    return yhats_signal
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
    points[sub.time.≈maximum(sub.time)] .= Ref(Point2f(NaN)) # terrible hack, it will remove the last point from ploitting. better would be to loop the lines! with views of the dataframe...


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
