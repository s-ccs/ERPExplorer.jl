"""
    formula_DOMs(variables)
Create widgets to control all model variables.\\

Arguments:\\
- `variables::Vector{Pair{Symbol}}` - vector of key-value pairs with information about the model formula terms.

Actions:
- Extract ranges of term values.\\
- Create widgets for each term (`Slider` for continuous, `SelectSet` for categorical).\\
- Creating the formula with checkboxes and translating to HTML code.\\
- Convert checkboxes to Observables.\\ 

**Return Values:**\\
- `formula_defaults::Dict{Symbol, Observable{Bool}}` - formula widgets with default values.\\
- `formula_toggle::Observable{Vector{Any}}` - formula widgets with all values and toggle value.\\
- `formula_DOM::Hyperscript.Node{Hyperscript.HTMLSVG}` - HTML element that can be displayed to interact with the the formula.\\
- `formula_values::Vector{Pair{Symbol}}` - formula widgets with all values.\\
"""
function formular_widgets(variables)
    formula_values = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in formula_values]
    checkboxes = [Bonito.Checkbox(false) for k in formula_values]
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

    formula_DOM = Row(widget_names...)
    widget_values = map(nw -> nw[2].value, widgets)
    checkbox_values = map(c -> c.value, checkboxes)

    formula_toggle =
        lift(widget_values..., checkbox_values...; ignore_equal_values = true) do args...
            result = []
            for i = 1:length(args[1:end/2])
                c = args[i+length(args)/2]
                w = args[i]
                push!(result, widgets[i][1] => (map(identity, c), map(identity, w)))
            end
            return result
        end
    formula_defaults = Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables))

    return formula_defaults, formula_toggle, formula_DOM, formula_values
end

"""
    get_ERP_data(model, widget_signal, channel)
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
function get_ERP_data(model, widget_signal, channel)

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
