function variable_legend(name, values::AbstractRange{<:Number}, palettes)
    range, cmap = palettes[name][:colormap]
    return S.Colorbar(limits=range, colormap=cmap, label=string(name))
end

function variable_legend(name, values::Set, palettes)
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
widget_value(x::Vector; resolution=1) = Float64(x[1]):0.5:Float64(x[end])

"""
    formular_widgets(model_variables)

Creates widgets to control each variable of a model.
Return values:
* `widget_signal`: a signal that emits a dictionary with the current values of the widgets.
* `formular_widget`: The HTML element that can be displayed to interact with the the widgets
* `value_ranges`: A dictionary with the value ranges of each variable.
"""
function formular_widgets(variables, formular)
    value_ranges = [k => value_range(v) for (k, v) in variables]
    widgets = [k => widget(v) for (k, v) in value_ranges]
    widget_names = [formular_text("0 ~ 1")]
    for (name, w) in widgets
        push!(widget_names, formular_text("+"), dropdown(name, w))
    end
    formular_widget = D.FlexRow(widget_names...)
    widget_values = map(nw -> nw[2].value, widgets)
    widget_signal = lift(widget_values...; ignore_equal_values=true) do args...
        result = []
        for (i, widget_value) in enumerate(args)
            # map(identity) -> make a vector with concrete element type
            push!(result, widgets[i][1] => map(identity, widget_value))
        end
        return result
    end
    return widget_signal, formular_widget, value_ranges
end

function effects_signal(model, widget_signal)
    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)
    on(widget_signal; update=true) do widget_values
        @show widget_values
        effect_dict = Dict(k => widget_value(wv) for (k, wv) in widget_values if !isempty(wv))
        eff = effects(effect_dict, model)
        for (k, wv) in widget_values
            if isempty(wv)
                eff[!, k] .= "typical_value"
            end
        end

        filter!(x -> x.channel == 1, eff)
        effects_signal[] = eff
    end
    return effects_signal
end



function plot_data(data, value_ranges, categorical_vars, continuous_vars)
    mpalette = [:circle, :star4, :xcross, :diamond]
    cpalette = Makie.wong_colors()
    cat_styles = [:color => cpalette, :marker => mpalette]
    cat_values = [unique(data[!, cat]) for cat in categorical_vars]
    scatter_styles = [cat => (style[1] => Dict(zip(vals, style[2]))) for (style, vals, cat) in zip(cat_styles, cat_values, categorical_vars)]
    @show scatter_styles
    continous_styles = [:colormap => :viridis, :colormap => :heat]
    continuous_values = [extrema(data[!, con]) for con in continuous_vars]
    line_styles = [cat => (style[1] => (val, style[2])) for (style, val, cat) in zip(continous_styles, continuous_values, continuous_vars)]

    function create_plot!(plots, data, catvars, vars)
        selector = [(name => x -> x .== var) for (name, var) in zip(catvars, vars)]
        sub = subset(data, selector...)
        points = Point2f.(sub.time, sub.yhat)
        args = [kw => vals[val] for (val, (name, (kw, vals))) in zip(vars, scatter_styles)]
        line_args = [kw => cmap for (name, (kw, (lims, cmap))) in line_styles]
        line_args2 = [:colorrange => lims for (name, (kw, (lims, cmap))) in line_styles]
        line_args3 = [:color => sub[!, name] for name in continuous_vars]
        push!(plots, S.Scatter(points; markersize=10, args...))
        push!(plots, S.Lines(points; line_args..., line_args2..., line_args3...))
        return
    end

    gridmax = 1
    legend_entries = []
    if length(categorical_vars) >= 2
        cat1 = categorical_vars[end]
        cat2 = categorical_vars[end-1]
        values1 = cat_values[end]
        values2 = cat_values[end-1]
        gridmax = length(values1)
        var_values = [categorical_vars[1:end-2] .=> Set.(cat_values[1:end-2]); map(n -> n => 1:1, continuous_vars)]
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
        append!(legend_entries, value_ranges)
        plots = PlotSpec[]
        for vars in Iterators.product(cat_values...)
            create_plot!(plots, data, categorical_vars, vars)
        end
        axes = [S.Axis(; plots=plots)]
    end
    palettes = Dict(map(((k, v),) -> k => Dict(v), vcat(line_styles, scatter_styles)))
    legends = map(legend_entries) do (k, v)
        return variable_legend(k, v, palettes)
    end
    return S.GridLayout([(1, 1) => S.GridLayout(axes), (:, 2) => S.GridLayout(legends)])
end
