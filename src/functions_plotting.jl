
"""
    update_grid(data, formula_values, categorical_vars, continuous_terms, mapping_obs)
Plot and update the interactive dashboard using AlgebraOfGraphics.

Arguments:\\
- `data::DataFrame` - the result of `effects(Dict(...), model)` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- `formula_values::Vector{Pair{Symbol}}` - value range for continuous variables, levels for categorical.\\
- `categorical_vars::Vector{Symbol}` - categorical terms.\\
- `continuous_terms::Vector{Symbol}` - continuous terms.\\
- `mapping::Dict{Symbol, Symbol}` - dictionary with dropdown menus and their default values.\\

Action:\\
- Build AoG layers for lines and scatter, with optional faceting and scales.\\

**Return Value:** `Makie.GridLayoutSpec`.
"""
function update_grid(data, formula_values, cat_terms, continuous_terms, mapping_obs)
    mapping_state = to_value(mapping_obs)

    cat_active = Dict(cat => data[1, cat] != "typical_value" for cat in cat_terms)
    cont_active = Dict(cont => data[1, cont] != "typical_value" for cont in continuous_terms)

    plot_data = copy(data)
    max_time = maximum(plot_data.time)
    plot_data[plot_data.time .≈ max_time, :yhat] .= NaN

    cat_color = get(cat_active, mapping_state[:color], false) ? mapping_state[:color] : nothing
    cat_marker = get(cat_active, mapping_state[:marker], false) ? mapping_state[:marker] : nothing
    cat_linestyle =
        get(cat_active, mapping_state[:linestyle], false) ? mapping_state[:linestyle] : nothing

    row_term = mapping_state[:row]
    col_term = mapping_state[:col]

    facet_aes = Dict{Symbol,Any}()
    if row_term != :none
        facet_aes[:row] = row_term => AlgebraOfGraphics.presorted
    end
    if col_term != :none
        facet_aes[:col] = col_term => AlgebraOfGraphics.presorted
    end

    scatter_aes = Dict{Symbol,Any}()
    if cat_color !== nothing
        scatter_aes[:color] = cat_color => AlgebraOfGraphics.presorted
    end
    if cat_marker !== nothing
        scatter_aes[:marker] = cat_marker => AlgebraOfGraphics.presorted
    end

    line_aes = Dict{Symbol,Any}()
    if cat_linestyle !== nothing
        line_aes[:linestyle] = cat_linestyle => AlgebraOfGraphics.presorted
    end

    active_cont = filter(cont -> get(cont_active, cont, false), continuous_terms)
    has_cont = !isempty(active_cont)
    if has_cont
        cont_term = first(active_cont)
        if cat_color !== nothing
            line_aes[:color] = cont_term => AlgebraOfGraphics.scale(:color2)
        else
            line_aes[:color] = cont_term
        end
    elseif cat_color !== nothing
        line_aes[:color] = cat_color => AlgebraOfGraphics.presorted
    end

    base = AlgebraOfGraphics.data(plot_data) *
           AlgebraOfGraphics.mapping(:time, :yhat; pairs(facet_aes)...)

    default_color = RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0)
    scatter_visual_kwargs = Pair{Symbol,Any}[]
    line_visual_kwargs = Pair{Symbol,Any}[]
    if cat_color === nothing && !has_cont
        push!(scatter_visual_kwargs, :color => default_color)
        push!(line_visual_kwargs, :color => default_color)
    end

    scatter_layer = AlgebraOfGraphics.mapping(; pairs(scatter_aes)...) *
                    AlgebraOfGraphics.visual(Scatter; markersize = 10, scatter_visual_kwargs...)
    line_layer = AlgebraOfGraphics.mapping(; pairs(line_aes)...) *
                 AlgebraOfGraphics.visual(Lines; line_visual_kwargs...)

    spec = base * (line_layer + scatter_layer)

    scales_kwargs = Dict{Symbol,Any}()
    if cat_color !== nothing
        scales_kwargs[:Color] = (; palette = Makie.wong_colors())
    end
    if cat_marker !== nothing
        scales_kwargs[:Marker] = (; palette = [:circle, :xcross, :star4, :diamond])
    end
    if cat_linestyle !== nothing
        scales_kwargs[:LineStyle] = (; palette = [:solid, :dot, :dash])
    end
    if has_cont
        cont_term = first(active_cont)
        scale_key = cat_color !== nothing ? :color2 : :Color
        scales_kwargs[scale_key] =
            (; colormap = :viridis, colorrange = extrema(data[!, cont_term]))
    end
    pop!(scales_kwargs, :Linestyle, nothing)

    spec_layout = AlgebraOfGraphics.draw_to_spec(
        spec,
        AlgebraOfGraphics.scales(; pairs(scales_kwargs)...);
        facet = (;
            linkxaxes = :none,
            linkyaxes = :none,
            hidexdecorations = false,
            hideydecorations = false,
        ),
    )

    return S.GridLayout([(1, 1) => spec_layout])
end
