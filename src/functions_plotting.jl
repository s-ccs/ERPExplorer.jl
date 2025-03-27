
"""
    update_grid(data, formula_values, categorical_vars, continuous_terms, mapping_obs)
Plotting and updating an interactive dashboard.

 Arguments:\\
- `data::DataFrame` - the result of `effects(Dict(...), model) ` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- `formula_values::Vector{Pair{Symbol}}` - value range for continuous variables, levels for categorical.\\
- `categorical_vars::Vector{Symbol}` - categorical terms.\\
- `continuous_terms::Vector{Symbol}` - continuous terms.\\
- `mapping::Dict{Symbol, Symbol}` - dictionary with dropdown menus and their default values.\\

Action:\\
- Create default palettes for colors, markers, line styles, and color styles for continuous values.\\
- Check that the terms are not empty.\\
- Plot the dashboard.\\
- Define line and scatter styles for the line plot.\\
- Add line and scatter styles to the legend.

**Return Value:** `Makie.GridLayoutSpec`.
"""
function update_grid(data, formula_values, cat_terms, continuous_terms, mapping_obs)
    # Convert observable mapping to values
    mapping = to_value(mapping_obs)

    # Identify is categorical term activated
    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in cat_terms)
    # Identify is continuous term activated
    cont_active =
        Dict(cont => data[1, cont] != "typical_value" for cont in continuous_terms)
    # Retrieve levels for selected and unselected categorical terms
    cat_levels = [unique(data[!, cat]) for cat in cat_terms] # empty unless selected

    # Prepare styles for categorical and continuous variables
    scatter_styles, line_styles = prepare_styles(
        data,
        cat_terms,
        continuous_terms,
        mapping,
        cat_active,
        cont_active,
        cat_levels,
    )

    col_term = mapping[:col] # not used yet
    row_term = mapping[:row] # not used yet

    legend_entries =
        [n => v for (n, v) in formula_values if merge(cat_active, cont_active)[n]]

    row_levels =
        row_term == :none ? [""] :
        [v for (v, n) in zip(cat_levels, cat_terms) if n == row_term][1]
    col_levels =
        col_term == :none ? [""] :
        [v for (v, n) in zip(cat_levels, cat_terms) if n == col_term][1]


    # Initialize matrix of plot axes
    axes = Matrix{Makie.BlockSpec}(undef, length(row_levels), length(col_levels))

    for (r_ix, row_level) in enumerate(row_levels)
        for (c_ix, col_level) in enumerate(col_levels)
            plots = PlotSpec[]

            # Filter data based on row and column levels
            subdata = filter_facet_data(data, row_term, col_term, row_level, col_level)

            active_cat_vars = Dict(
                term => level for
                (term, level) in zip(cat_terms, cat_levels) if cat_active[term]
            )
            if row_term != :none
                active_cat_vars[row_term] = [row_level]
            end
            if col_term != :none
                active_cat_vars[col_term] = [col_level]
            end

            # Iterate over categorical levels to define styles
            for level_grid in Iterators.product(collect(values(active_cat_vars))...)
                if !isempty(level_grid) && level_grid[1] .== "typical_value"
                    continue
                end
                dict_grid = Dict(collect(keys(active_cat_vars)) .=> level_grid)
                define_style_scatter_lines!(
                    plots,
                    subdata,
                    dict_grid,
                    scatter_styles,
                    line_styles,
                    continuous_terms,
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

    res = S.GridLayout([(1, 1) => S.GridLayout(axes), (:, 2) => S.GridLayout(legends)])
    return res
end


function prepare_styles(
    data,
    cat_terms,
    continuous_terms,
    mapping,
    cat_active,
    cont_active,
    cat_levels,
)
    # Define palettes for markers, colors, line and ?? styles
    mpalette = [:circle, :xcross, :star4, :diamond]
    cpalette = Makie.wong_colors()
    lpalette = [:solid, :dot, :dash]
    continuous_styles = [:viridis, :heat, :RdBu]

    # Assign styles to categorical variables
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
    # Assign styles to continuous variables
    continuous_values = [extrema(data[!, con]) for con in continuous_terms]
    # Check for equal min/max values

    if isempty(continuous_terms) ||
       isempty(continuous_values) ||
       continuous_values[1] == Float64 && continuous_values[1] == continuous_values[2]
        # if no continuous variable, use the scatter-color for plotting
        line_styles = Dict()

    else
        active_terms = filter(cont -> cont_active[cont], continuous_terms)
        line_styles = Dict(
            cont => (:colormap => (val, style)) for (style, val, cont) in
            zip(continuous_styles, continuous_values, active_terms)
        )

    end
    return scatter_styles, line_styles
end


function filter_facet_data(data, row_term, col_term, row_level, col_level)
    # Subset data based on row and column levels
    subdata = data
    if col_term != :none
        subdata = subset(subdata, col_term => ByRow(==(col_level)))
    end
    if row_term != :none
        subdata = subset(subdata, row_term => ByRow(==(row_level)))
    end
    return subdata
end
