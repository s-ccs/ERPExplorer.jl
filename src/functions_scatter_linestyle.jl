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
    points[sub.time.≈maximum(sub.time)] .= Ref(Point2f(NaN))
    # terrible hack, it will remove the last point from ploitting. 
    #better would be to loop the lines! with views of the dataframe...

    args = [
        scatter_styles[term][1] => scatter_styles[term][2][val] for
        (term, val) in vars if term ∈ keys(scatter_styles)
    ]

    if isempty(line_styles)
        line_cmap = []
        line_crange = []
        line_color = args
        if isempty(args) || !any(x -> x[1] == :color, args)
            push!(args, :color => :black) # default color for lines
        end

    else
        line_cmap = [kw => cmap for (_, (kw, (_, cmap))) in line_styles]
        line_crange = [:colorrange => lims for (_, (_, (lims, _))) in line_styles]
        line_color = [:color => sub[!, name] for name in continuous_vars]

    end

    push!(plots, S.Scatter(points; markersize = 10, args...))
    #@show line_color
    push!(plots, S.Lines(points; line_cmap..., line_crange..., line_color...))
    return
end
