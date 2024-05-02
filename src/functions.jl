function variable_legend(name, values::AbstractRange{<:Number}, palettes)
    range, cmap = palettes[name][:colormap]
    return S.Colorbar(limits=range, colormap=cmap, label=string(name))
end

function variable_legend(name, values::Set, palettes)
    #    @debug "variable_legend" palettes name
    palette = palettes[name]
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
        return MarkerElement(marker=marker_lookup(c), color=marker_color_lookup(c))
    end
    return S.Legend(elements, conditions)
end

widget_value(w::Vector{<:String}; resolution=1) = w
widget_value(x::Vector; resolution=1) = x[1] ≈ x[end] ? Float64[] : range(Float64(x[1]), Float64(x[end]), length=5)

"""
    formular_widgets(model_variables)

Creates widgets to control each variable of a model.
Return values:
* `widget_signal`: a signal that emits a dictionary with the current values of the widgets.
* `formular_widget`: The HTML element that can be displayed to interact with the the widgets
* `value_ranges`: A dictionary with the value ranges of each variable.
"""
function formular_widgets(variables)
    value_ranges = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in value_ranges]
    checkboxes = [Checkbox(true) for k in value_ranges]
    widget_names = [formular_text("0 ~ 1")]
    for k in 1:length(widgets)
        c = checkboxes[k]
        name = widgets[k].first
        w = widgets[k].second
        push!(widget_names, formular_text("+"), formular_text(c), dropdown(name, w))

    end
    formular_widget = Row(widget_names...)

    widget_values = map(nw -> nw[2].value, widgets)
    checkbox_values = map(c -> c.value, checkboxes)
    #    @debug typeof(widget_values)
    widget_signal = lift(widget_values..., checkbox_values...; ignore_equal_values=true) do args...
        result = []
        for i in 1:length(args[1:end/2])
            c = args[i+length(args)/2]
            w = args[i]
            #            @debug c w
            # map(identity) -> make a vector with concrete element type
            push!(result, widgets[i][1] => (map(identity, c), map(identity, w)))
        end
        return result
    end
    return Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables)), widget_signal, formular_widget, value_ranges
end

function effects_signal(model, widget_signal)
    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)
    @debug widget_signal
    on(widget_signal; update=true) do widget_values
        #        @debug widget_values


        effect_dict = Dict(k => widget_value(wv[2]) for (k, wv) in widget_values if !isempty(wv) && wv[1])
        #    @debug widget_values
        #    @debug effect_dict
        eff = effects(effect_dict, model)
        for (k, wv) in widget_values
            if isempty(wv[2]) || !wv[1]
                eff[!, k] .= "typical_value"
            end
        end

        filter!(x -> x.channel == 1, eff)
        effects_signal[] = eff
    end
    return effects_signal
end



"""
    - data: effects(Dict(...),m) output ::DataFrames
    - value_ranges
    - categorical_vars
    - continuous_vars
    - mapping: Dict name=>property

"""
function plot_data(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)
    #mapping = Dict(:color => :color, :fruit => :marker)#, :fruit => :linestyle) will work in Makie 0.21
    mapping = to_value(mapping_obs)
    @debug "mapping" mapping
    mpalette = [:circle, :xcross, :star4, :diamond]
    cpalette = Makie.wong_colors()
    lpalette = [:solid, :dot, :dash]
    continuous_styles = [:viridis, :heat, :RdBu]

    #cat_styles = [:color => cpalette, :marker => mpalette]

    # is the formula term even active?
    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in categorical_vars)
    cont_active = Dict(cont => data[1, cont] != "typical_value" for cont in continuous_vars)
    #    @debug "active?" cat_active cont_active
    # get the categorical values
    cat_values = [unique(data[!, cat]) for cat in categorical_vars]

    # define what is mapped according to what for categorical
    scatter_styles = []
    for (vals, cat) in zip(cat_values, categorical_vars)
        if !cat_active[cat]
            continue
        end

        for (target, pal) = zip([:color, :marker, :linestyle], (cpalette, mpalette, lpalette))
            if mapping[target] == cat
                p = cat => (target => Dict(zip(vals, pal)))
                push!(scatter_styles, p)
            end
        end
    end
    @debug "scatter_styles" scatter_styles



    continuous_values = [extrema(data[!, con]) for con in continuous_vars]
    if isempty(continuous_vars)
        # if no continuous variable, use the scatter-color for plotting
        line_styles = []

    else
        line_styles = [cont => (:colormap => (val, style)) for (style, val, cont) in zip(continuous_styles, continuous_values, continuous_vars) if cont_active[cont]]
    end


    @debug "line_styles" line_styles

    function create_plot!(plots, data, catvars, vars)

        selector = [(name => x -> x .== var) for (name, var) in zip(catvars, vars)]
        sub = subset(data, selector...)

        points = Point2f.(sub.time, sub.yhat)
        #        @debug "v" vars scatter_styles
        args = [kw => vals[val] for (val, (name, (kw, vals))) in zip(vars, scatter_styles)]
        if isempty(line_styles)
            line_args = []
            line_args2 = []
            line_args3 = args
            if !any(x -> x[1] .== :color, line_args3)
                push!(args, :color => :black)
            end

        else
            line_args = [kw => cmap for (name, (kw, (lims, cmap))) in line_styles]
            line_args2 = [:colorrange => lims for (name, (kw, (lims, cmap))) in line_styles]
            line_args3 = [:color => sub[!, name] for name in continuous_vars]
        end
        push!(plots, S.Scatter(points; markersize=10, args...))
        push!(plots, S.Lines(points; line_args..., line_args2..., line_args3...))
        return
    end

    gridmax = 1
    legend_entries = []
    if length(categorical_vars) > 2
        @debug "more than 2 cats"
        append!(legend_entries, var_values)
        axes = Matrix{Makie.BlockSpec}(undef, length(values1), length(values2))
        for (i, catval1) in enumerate(values1)
            for (k, catval2) in enumerate(values2)
                plots = PlotSpec[]
                subdata = subset(data, cat1 => x -> x .== catval1, cat2 => x -> x .== catval2)
                for vars in Iterators.product(cat_values[1:end-2]...)
                    create_plot!(plots, subdata, categorical_vars[1:end-2], vars)
                end
                axes[i, k] = S.Axis(; title="$cat1: $catval1, $cat2: $catval2", plots=plots)
            end
        end
    else
        # what has currently a legend?
        append!(legend_entries, [n => v for (n, v) in value_ranges if merge(cat_active, cont_active)[n]])

        # keep track of plotelements
        plots = PlotSpec[]

        active_cat_vars = [n for n in categorical_vars if cat_active[n]]
        active_cat_values = [v for (n, v) in zip(categorical_vars, cat_values) if cat_active[n]]

        for vars in Iterators.product(active_cat_values...)
            @debug vars
            if !isempty(vars) && vars[1] .== "typical_value"
                continue
            end

            create_plot!(plots, data, active_cat_vars, vars)
        end
        axes = [S.Axis(; plots=plots)]
    end
    palettes = Dict(map(((k, v),) -> k => Dict(v), vcat(line_styles, scatter_styles)))
    legends = map(legend_entries) do (k, v)
        return variable_legend(k, v, palettes)
    end
    return S.GridLayout([(1, 1) => S.GridLayout(axes), (:, 2) => S.GridLayout(legends)])
end
