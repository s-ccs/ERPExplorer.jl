
"""
    plot_data(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)
Plotting an interactive dashboard.

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
function plot_data(data, value_ranges, cat_terms, continuous_vars, mapping_obs)
    mapping = to_value(mapping_obs)

    mpalette = [:circle, :xcross, :star4, :diamond]
    cpalette = Makie.wong_colors()
    lpalette = [:solid, :dot, :dash]
    continuous_styles = [:viridis, :heat, :RdBu]

    #cat_styles = [:color => cpalette, :marker => mpalette]

    # is the formula term even active?
    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in cat_terms)
    cont_active = Dict(cont => data[1, cont] != "typical_value" for cont in continuous_vars)

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
                subset(data, col_term => level -> level .== col_level) # Why subdata is overwritten?
            subdata =
                row_term == :none ? subdata :
                subset(subdata, row_term => level -> level .== row_level)

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


"""
    define_scatter_line_style!(plots, data, vars, scatter_styles, line_styles, continuous_vars)
Define styling of lines and points (scatter).

Actions:\\
- subset the data.\\
- select points and plot scatter. Define scatter style: markersize and color.\\
- plot lines and define line style: colormap, color range, color.\\

Arguments:\\
- `plots::Vector{Makie.PlotSpec}` - an empty SpecApi list to push into parts of the layout.\\
- `data::DataFrame` - a DataFrame with predicted values to be subsetted.\\
- `vars::Dict{Any, Any}` contains the levels to be plotted.\\
- `scatter_styles::Dict{Any, Any}` - define colors of scatter.\\
- `line_styles:: Dict{Symbol, Pair{Symbol, Tuple{Tuple{String, String}, Symbol}}}` - define line styles: colormap, color range, color.\\
- `continuous_vars::Vector{Symbol}` - continuous terms.

**Return Value:** `Makie.GridLayoutSpec`.
"""
function define_scatter_line_style!(
    plots,
    data,
    vars,
    scatter_styles,
    line_styles,
    continuous_vars,
)
    selector = [(name => x -> x .== var) for (name, var) in vars]

    sub = subset(data, selector...) # but len(data) and len(sub) are equal...

    @assert !isempty(sub) "this shouldn't be empty..."
    points = Point2f.(sub.time, sub.yhat)
    points[sub.time.≈maximum(sub.time)] .= Ref(Point2f(NaN)) # terrible hack, it will remove the last point from ploitting. better would be to loop the lines! with views of the dataframe...

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
        @debug line_args
    end
    push!(plots, S.Scatter(points; markersize = 10, args...))

    push!(plots, S.Lines(points; line_args..., line_args2..., line_args3...))
    return
end
