"""
    formular_widgets(variables)
Creates widgets to control each variable of a model.\\

Arguments:\\
- `variables::Vector{Pair{Symbol}}` - vector of key-value pairs with information about the model formula terms.

Actions:
- Extract ranges of term values.\\
- Create widgets for each term (`Slider` for continuous, `SelectSet` for categorical).\\
- Creating the formula with checkboxes and translating to HTML code.\\
- Convert checkboxes to Observables.\\ 

**Return Values:**\\
- `widget_checkbox`: Dictionary with the current values of the widgets (term => values).\\
- `widget_signal`: widget_checkbox but as Observable, a signal that emits a dictionary with the current values of the widgets.\\
- `formular_widget`: The HTML element that can be displayed to interact with the the widgets.\\
- `value_ranges`: A dictionary containing the value ranges of each formula term.\\
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
- `model::UnfoldLinearModel{Float64}` - vector of key-value pairs with information about the model formula terms.\\
- `widget_signal::Observable{Vector{Any}}` - a signal that emits a dictionary with the current values of the widgets.\\
- `channel::Observable{Int64}` - number of selected channels.\\

Actions:\\
- Compute predicted value (yhat) of the given model using `effects`.\\
- Create `DataFrame` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- Make it Observable.\\

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
