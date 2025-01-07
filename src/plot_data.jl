
"""
    plot_data(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)
- `data`: effects(Dict(...), m) 
- `value_ranges`:
- `categorical_vars`:
- `continuous_vars`:
- `mapping`: Dict name=>property.

**Return Value:** `DataFrames`.
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

        for (target, pal) in
            zip([:color, :marker, :linestyle], (cpalette, mpalette, lpalette))
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
        line_styles = Dict(
            cont => (:colormap => (val, style)) for (style, val, cont) in
            zip(continuous_styles, continuous_values, continuous_vars) if
            cont_active[cont]
        )
    end

    col_term = mapping[:col]
    row_term = mapping[:row]

    legend_entries =
        [n => v for (n, v) in value_ranges if merge(cat_active, cont_active)[n]]

    row_levels =
        row_term == :none ? [""] :
        [v for (v, n) in zip(cat_levels, cat_terms) if n == row_term][1]
    col_levels =
        col_term == :none ? [""] :
        [v for (v, n) in zip(cat_levels, cat_terms) if n == col_term][1]

    axes = Matrix{Makie.BlockSpec}(undef, length(row_levels), length(col_levels))

    for (r_ix, row_level) in enumerate(row_levels)
        for (c_ix, col_level) in enumerate(col_levels)
            plots = PlotSpec[]
            subdata = data
            subdata =
                col_term == :none ? data :
                subset(data, col_term => level -> level .== col_level)
            subdata =
                row_term == :none ? subdata :
                subset(subdata, row_term => level -> level .== row_level)


            active_cat_vars = Dict(
                term => level for
                (term, level) in zip(cat_terms, cat_levels) if cat_active[term]
            )# & 
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
                create_plot!(
                    plots,
                    subdata,
                    Dict(collect(keys(active_cat_vars)) .=> level_grid),
                    scatter_styles,
                    line_styles,
                    continuous_vars,
                )
            end
            axes[r_ix, c_ix] = S.Axis(; plots = plots)
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
