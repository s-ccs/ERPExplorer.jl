"""
    define_style_scatter_lines!(plots, data, dict_grid, scatter_styles, line_styles, continuous_vars)
Define styling of lines and points (scatter).

Actions:\\
- subset the data.\\
- select points and plot scatter. Define scatter style: markersize and color.\\
- plot lines and define line style: colormap, color range, color.\\

Arguments:\\
- `plots::Vector{Makie.PlotSpec}` - an empty SpecApi list to push into parts of the layout.\\
- `data::DataFrame` - a DataFrame with predicted values to be subsetted.\\
- `dict_grid::Dict{Any, Any}` - dictionary with one of the possible combination of selected categorical terms.\\
- `scatter_styles::Dict{Any, Any}` - define colors of scatter.\\
- `line_styles:: Dict{Symbol, Pair{Symbol, Tuple{Tuple{String, String}, Symbol}}}` - define line styles: colormap, color range, color.\\
- `continuous_vars::Vector{Symbol}` - continuous terms.

**Return Value:** `Makie.GridLayoutSpec`.
"""
function define_style_scatter_lines!(
    plots,
    data,
    dict_grid,
    scatter_styles,
    line_styles,
    continuous_vars,
)
    selector = [(name => x -> x .== var) for (name, var) in dict_grid]

    sub = subset(data, selector...) # but len(data) and len(sub) are equal...

    @assert !isempty(sub) "This shouldn't be empty..."
    points = Point2f.(sub.time, sub.yhat)
    points[sub.time.≈maximum(sub.time)] .= Ref(Point2f(NaN))
    # terrible hack, it will remove the last point from ploitting. 
    #better would be to loop the lines! with views of the dataframe...

    # define style for scatter 
    args = [
        scatter_styles[term][1] => scatter_styles[term][2][val] for
        (term, val) in dict_grid if term ∈ keys(scatter_styles)
    ]

    # define style for lines and scatter
    if isempty(line_styles)
        line_cmap = []
        line_crange = []

        args = convert(Vector{Pair{Symbol,Any}}, args)
        if isempty(args) || !any(x -> x[1] == :color, args)
            push!(args, :color => RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0)) # set scatter color to default black 
        end
        line_color = [:color => Dict(args)[:color]]

    else # if contionus terms are present
        line_cmap = [kw => cmap for (_, (kw, (_, cmap))) in line_styles]
        line_crange = [:colorrange => lims for (_, (_, (lims, _))) in line_styles]
        line_color = [:color => sub[!, name] for name in continuous_vars]
    end

    push!(plots, S.Scatter(points; markersize = 10, args...))
    push!(plots, S.Lines(points; line_cmap..., line_crange..., line_color...))
    return
end
