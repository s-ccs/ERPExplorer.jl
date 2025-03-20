
"""
    update_grid(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)
Plotting and updating an interactive dashboard.

 Arguments:\\
- `data::DataFrame` - the result of `effects(Dict(...), model) ` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- `value_ranges::Vector{Pair{Symbol}}` - value range for continuous variables, levels for categorical.\\
- `categorical_vars::Vector{Symbol}` - categorical terms.\\
- `continuous_vars::Vector{Symbol}` - continuous terms.\\
- `mapping::Dict{Symbol, Symbol}` - dictionary with dropdown menus and their default values.\\

Action:\\
- Create default palettes for colors, markers, line styles, and color styles for continuous values.\\
- Check that the terms are not empty.\\
- Plot the dashboard.\\
- Define line and scatter styles for the line plot.\\
- Add line and scatter styles to the legend.

**Return Value:** `Makie.GridLayoutSpec`.
"""
function update_grid(data, value_ranges, cat_terms, continuous_vars, mapping_obs)
    # Convert observable mapping to values
    mapping = to_value(mapping_obs)

    # Identify activated categorical and continuous variables
    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in cat_terms)
    cont_active = Dict(cont => data[1, cont] != "typical_value" for cont in continuous_vars)
#@debug cat_active
    # Retrieve unique categorical levels
    cat_levels = [unique(data[!, cat]) for cat in cat_terms]

    # Prepare styles for categorical and continuous variables
    scatter_styles, line_styles = prepare_styles(
        data,
        cat_terms,
        continuous_vars,
        mapping,
        cat_active,
        cont_active,
        cat_levels,
    )

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
                # create a new term => values (e.g. animal => [fish,cow] ) Dict
                define_scatter_line_style!(
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


function prepare_styles(
    data,
    cat_terms,
    continuous_vars,
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
