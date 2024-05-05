function variable_legend(name, values::AbstractRange{<:Number}, palette::Dict)
    range, cmap = palette[:colormap]
    return S.Colorbar(limits=range, colormap=cmap, label=string(name))
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

    widget_signal = lift(widget_values..., checkbox_values...; ignore_equal_values=true) do args...
        result = []
        for i in 1:length(args[1:end/2])
            c = args[i+length(args)/2]
            w = args[i]

            push!(result, widgets[i][1] => (map(identity, c), map(identity, w)))
        end
        return result
    end
    return Dict(k => c for (c, (k, v)) in zip(checkbox_values, variables)), widget_signal, formular_widget, value_ranges
end

function effects_signal(model, widget_signal, channel)
    effects_signal = Observable{Any}(nothing; ignore_equal_values=true)

    onany(widget_signal, channel; update=true) do widget_values, chan



        effect_dict = Dict(k => widget_value(wv[2]) for (k, wv) in widget_values if !isempty(wv) && wv[1])
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
- plots is a spec-api list to push into
- data is the dataframe to be subsetted
- vars contains the levels to be plotted
"""
function create_plot!(plots, data, vars, scatter_styles, line_styles, continuous_vars)

    selector = [(name => x -> x .== var) for (name, var) in vars]

    sub = subset(data, selector...)
    @assert !isempty(sub) "this shouldnt be empty..."
    points = Point2f.(sub.time, sub.yhat)
    points[sub.time.≈maximum(sub.time)] .= Ref(Point2f(NaN)) # terrible hack, it will remove the last point from ploitting. better would be to loop the lines! with views of the dataframe...


    #    @debug "create_plot!" scatter_styles vars
    #args = [kw => vals[val] for (val, (name, (kw, vals))) in zip(vars, scatter_styles)]
    args = [scatter_styles[term][1] => scatter_styles[term][2][val] for (term, val) in vars if term ∈ keys(scatter_styles)]

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
    push!(plots, S.Scatter(points; markersize=10, args...))

    push!(plots, S.Lines(points; line_args..., line_args2..., line_args3...))
    return
end




"""
    - data: effects(Dict(...),m) output ::DataFrames
    - value_ranges
    - cat_terms
    - continuous_vars
    - mapping: Dict name=>property

"""
function plot_data(data, value_ranges, cat_terms, continuous_vars, mapping_obs)
    #mapping = Dict(:color => :color, :fruit => :marker)#, :fruit => :linestyle) will work in Makie 0.21
    mapping = to_value(mapping_obs)

    mpalette = [:circle, :xcross, :star4, :diamond]
    cpalette = Makie.wong_colors()
    lpalette = [:solid, :dot, :dash]
    continuous_styles = [:viridis, :heat, :RdBu]

    #cat_styles = [:color => cpalette, :marker => mpalette]

    # is the formula term even active?
    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in cat_terms)
    cont_active = Dict(cont => data[1, cont] != "typical_value" for cont in continuous_vars)
    #    @debug "active?" cat_active cont_active
    # get the categorical values
    cat_levels = [unique(data[!, cat]) for cat in cat_terms]

    # define what is mapped according to what for categorical
    scatter_styles = Dict()
    for (vals, cat) in zip(cat_levels, cat_terms)
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



    continuous_values = [extrema(data[!, con]) for con in continuous_vars]
    if isempty(continuous_vars)
        # if no continuous variable, use the scatter-color for plotting
        line_styles = Dict()

    else
        line_styles = Dict(cont => (:colormap => (val, style)) for (style, val, cont) in zip(continuous_styles, continuous_values, continuous_vars) if cont_active[cont])
    end




    col_term = mapping[:col]
    row_term = mapping[:row]


    legend_entries = [n => v for (n, v) in value_ranges if merge(cat_active, cont_active)[n]]


    row_levels = row_term == :none ? [""] : [v for (v, n) in zip(cat_levels, cat_terms) if n == row_term][1]
    col_levels = col_term == :none ? [""] : [v for (v, n) in zip(cat_levels, cat_terms) if n == col_term][1]

    axes = Matrix{Makie.BlockSpec}(undef, length(row_levels), length(col_levels))


    for (r_ix, row_level) = enumerate(row_levels)
        for (c_ix, col_level) = enumerate(col_levels)
            plots = PlotSpec[]
            subdata = data
            subdata = col_term == :none ? data : subset(data, col_term => level -> level .== col_level)
            subdata = row_term == :none ? subdata : subset(subdata, row_term => level -> level .== row_level)


            active_cat_vars = Dict(term => level for (term, level) in zip(cat_terms, cat_levels) if cat_active[term])# & 
            if row_term != :none
                active_cat_vars[row_term] = [row_level]
            end
            if col_term != :none
                active_cat_vars[col_term] = [col_level]
            end
            for level_grid in Iterators.product(collect(values(active_cat_vars))...)
                if !isempty(level_grid) && level_grid[1] .== "typical_value"
                    continue
                end
                # create a new term => values (e.g. animal => [fish,cow] ) Dict
                create_plot!(plots, subdata, Dict(collect(keys(active_cat_vars)) .=> level_grid), scatter_styles, line_styles, continuous_vars)
            end
            axes[r_ix, c_ix] = S.Axis(; plots=plots)
        end
    end

    palettes = merge(line_styles, scatter_styles)

    legends = Union{Nothing,Makie.BlockSpec}[]
    for (term, levels) in legend_entries
        if haskey(palettes, term)
            push!(legends, variable_legend(term, levels, Dict(palettes[term])))
        end
    end

    if isempty(legends)
        return S.GridLayout(axes)
    else
        return S.GridLayout([(1, 1) => S.GridLayout(axes), (:, 2) => S.GridLayout(legends)])
    end

end
