"""
    formular_widgets(variables)
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
- `formula_toggle::Observable{Vector{Any}}` - formula widgets with toggle state,
  current raw widget value, and term type.\\
- `formula_DOM::Hyperscript.Node{Hyperscript.HTMLSVG}` - HTML element that can be displayed to interact with the the formula.\\
- `formula_values::Vector{Pair{Symbol}}` - formula widgets with all values.\\
"""
function formular_widgets(variables)
    formula_values = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in formula_values]
    term_types = [v[3] for (_k, v) in variables]
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

    formula_DOM = DOM.div(widget_names...; class = "erp-formula")
    widget_values = map(nw -> nw[2].value, widgets)
    checkbox_values = map(c -> c.value, checkboxes)

    formula_toggle = isempty(widgets) ? Observable(Any[]) :
        lift(widget_values..., checkbox_values...; ignore_equal_values = true) do args...
            result = []
            n_widgets = Int(length(args) ÷ 2)
            for i = 1:n_widgets
                c = args[i+n_widgets]
                w = args[i]
                # Keep an independent snapshot for equality checks; widget arrays may
                # be updated in place by the browser transport.
                push!(result, widgets[i][1] => (c, copy(w), term_types[i]))
            end
            return result
        end
    formula_defaults = Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables))

    return formula_defaults, formula_toggle, formula_DOM, formula_values
end

function effects_request(formula_toggle_on)
    yhat_dict = Dict{Symbol,Any}()
    active_terms = Set{Symbol}()

    for (k, v) in formula_toggle_on
        if !isempty(v) && v[1] && !isempty(v[2])
            push!(active_terms, k)
            yhat_dict[k] = widget_value(v[2], v[3])
        end
    end

    if isempty(yhat_dict)
        yhat_dict = Dict(:dummy => ["dummy"])
    end

    return yhat_dict, active_terms
end

function build_ERP_payload(model, formula_toggle_on, chan)
    yhat_dict, active_terms = effects_request(formula_toggle_on)
    yhats_all = effects(yhat_dict, model)
    return filter_ERP_payload(
        (data = yhats_all, all_data = yhats_all, active_terms = active_terms),
        chan,
    )
end

function filter_ERP_payload(effects_state, chan)
    isnothing(effects_state) && return nothing
    yhats_all = all_payload_data(effects_state)
    yhats_channel = yhats_all[yhats_all.channel .== chan, :]
    _, active_terms = unpack_erp_payload(effects_state, nothing)
    return (data = yhats_channel, all_data = yhats_all, active_terms = active_terms)
end

function all_payload_data(payload)
    if payload isa NamedTuple && haskey(payload, :all_data)
        return payload.all_data
    end
    data, _ = unpack_erp_payload(payload, nothing)
    return data
end

function event_selection_values(payload)
    data = all_payload_data(payload)
    if isnothing(data) || nrow(data) == 0 || !(:eventname in Symbol.(names(data)))
        return Any[nothing]
    end

    values = Any[]
    for value in unique(data.eventname)
        ismissing(value) || push!(values, value)
    end
    isempty(values) && return Any[nothing]
    return sort_values(values)
end

event_selection_label(value) = isnothing(value) ? "all events" : string(value)

function event_selection_index(values, selected_event)
    index = findfirst(value -> isequal(value, selected_event), values)
    return isnothing(index) ? 1 : index
end

function filter_ERP_event_payload(effects_state, selected_event)
    isnothing(effects_state) && return nothing
    yhats_all = all_payload_data(effects_state)
    filtered = if !isnothing(selected_event) && :eventname in Symbol.(names(yhats_all))
        yhats_all[isequal.(yhats_all.eventname, Ref(selected_event)), :]
    else
        yhats_all
    end
    _, active_terms = unpack_erp_payload(effects_state, nothing)
    return (data = filtered, all_data = filtered, active_terms = active_terms)
end

function mapped_categorical_terms(mapping)
    isnothing(mapping) && return Symbol[]
    terms = Symbol[]
    for value in values(mapping)
        if value isa Symbol
            value == :none && continue
            push!(terms, value)
        elseif value isa AbstractString
            value == "none" && continue
            push!(terms, Symbol(value))
        end
    end
    return sort!(collect(unique(terms)))
end

function topoplot_group_label(row, active_categorical_terms)
    isempty(active_categorical_terms) && return "All discrete terms"
    return join(["$(term)=$(row[term])" for term in active_categorical_terms], ", ")
end

function active_topoplot_terms(
    payload,
    categorical_terms,
    continuous_terms;
    additional_active_terms = Symbol[],
)
    data = all_payload_data(payload)
    _, active_terms = unpack_erp_payload(payload, nothing)
    if isnothing(data) || nrow(data) == 0
        return (
            status = :empty,
            message = "No data for current selection.",
            data = data,
            categorical = Symbol[],
            continuous = Symbol[],
        )
    end

    data_cols = Set(Symbol.(names(data)))
    active_set = active_term_set(active_terms, data_cols, vcat(categorical_terms, continuous_terms))
    union!(active_set, Set(Symbol.(additional_active_terms)))
    active_categorical = [
        term for term in categorical_terms if term in active_set && term in data_cols
    ]
    active_continuous = [
        term for term in continuous_terms if term in active_set && term in data_cols
    ]

    if !isempty(active_continuous)
        return (
            status = :disabled,
            message = "Topoplot series only supports discrete predictors.",
            data = data,
            categorical = active_categorical,
            continuous = active_continuous,
        )
    end

    return (
        status = :ok,
        message = "",
        data = data,
        categorical = active_categorical,
        continuous = active_continuous,
    )
end

function prepare_topoplot_series_data(
    payload,
    positions,
    categorical_terms,
    continuous_terms;
    group_col = :topoplot_group,
    additional_active_terms = Symbol[],
)
    isnothing(positions) && return (
        status = :disabled,
        message = "Topoplot series requires channel positions.",
        data = DataFrame(),
        mapping = (; col = :time, y = :yhat),
        groups = String[],
    )

    terms = active_topoplot_terms(
        payload,
        categorical_terms,
        continuous_terms;
        additional_active_terms = additional_active_terms,
    )
    terms.status == :ok || return (
        status = terms.status,
        message = terms.message,
        data = DataFrame(),
        mapping = (; col = :time, y = :yhat),
        groups = String[],
    )

    data = copy(terms.data)
    position_count = length(positions)
    channels = sort!(Int.(collect(unique(data.channel))))
    if position_count == 0 ||
       length(channels) != position_count ||
       any(ch -> !(1 <= ch <= position_count), channels)
        return (
            status = :disabled,
            message = "Channel positions do not match the current effects channels.",
            data = DataFrame(),
            mapping = (; col = :time, y = :yhat),
            groups = String[],
        )
    end

    if isempty(terms.categorical)
        groups = ["All discrete terms"]
        mapping = (; col = :time, y = :yhat)
    else
        data[!, group_col] = [
            topoplot_group_label(row, terms.categorical) for row in eachrow(data)
        ]
        groups = sort!(collect(unique(data[!, group_col])))
        mapping = (; col = :time, row = group_col, y = :yhat)
    end

    return (
        status = :ok,
        message = "",
        data = data,
        mapping = mapping,
        groups = groups,
    )
end

"""
    get_ERP_data(model, formula_toggle, channel_chosen)
Creates a dictionary with yhat values and more.\\

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - vector of key-value pairs with information about the model formula terms.\\
- `formula_toggle::Observable{Vector{Any}}` - a signal that emits a dictionary with the current values of the widgets.\\
- `channel_chosen::Observable{Int64}` - number of selected channels.\\

Actions:\\
- Compute predicted value (yhat) of the given model using `effects`.\\
- Create `DataFrame` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- Make it Observable.\\

**Return Value:** `yhats_signal::Observable{Any}` containing
`(data = selected-channel DataFrame, all_data = all-channel DataFrame, active_terms = Set{Symbol})`.
"""
function get_ERP_data(model, formula_toggle, channel_chosen)
    ERP_effects = get_ERP_effects(model, formula_toggle)
    return get_channel_ERP_data(ERP_effects, channel_chosen)
end

function get_ERP_effects(model, formula_toggle; session = nothing, on_effects = _ -> nothing)
    ERP_effects = Observable{Any}(nothing; ignore_equal_values = true)
    last_request = Ref{Any}(nothing)

    observe_all(session, formula_toggle; update = true) do formula_toggle_on
        t0 = time_ns()
        yhat_dict, active_terms = effects_request(formula_toggle_on)
        request = (yhat_dict, active_terms)
        isequal(last_request[], request) && return
        yhats_all = effects(yhat_dict, model)
        last_request[] = deepcopy(request)
        on_effects((time_ns() - t0) / 1e6)
        ERP_effects[] = (data = yhats_all, all_data = yhats_all, active_terms = active_terms)
    end

    return ERP_effects
end

function get_event_ERP_effects(ERP_effects, selected_event; session = nothing)
    ERP_event_effects = Observable{Any}(nothing; ignore_equal_values = true)

    observe_all(session, ERP_effects, selected_event; update = true) do effects_state, event
        ERP_event_effects[] = filter_ERP_event_payload(effects_state, event)
    end

    return ERP_event_effects
end

function get_channel_ERP_data(ERP_effects, channel_chosen; session = nothing)
    ERP_data = Observable{Any}(nothing; ignore_equal_values = true)

    observe_all(session, ERP_effects, channel_chosen; update = true) do effects_state, chan
        ERP_data[] = filter_ERP_payload(effects_state, chan)
    end

    return ERP_data
end

function observe_all(f, session, observables...; update = false)
    handles = isnothing(session) ? onany(f, observables...) : onany(f, session, observables...)
    update && f(map(to_value, observables)...)
    return handles
end
