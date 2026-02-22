
"""
    update_grid(data, formula_values, categorical_vars, continuous_terms, mapping_obs)
Plot and update the interactive dashboard using AlgebraOfGraphics.

Arguments:\\
- `data::DataFrame` - the result of `effects(Dict(...), model)` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- `formula_values::Vector{Pair{Symbol}}` - value range for continuous variables, levels for categorical.\\
- `categorical_vars::Vector{Symbol}` - categorical terms.\\
- `continuous_terms::Vector{Symbol}` - continuous terms.\\
- `mapping::Dict{Symbol, Symbol}` - dictionary with dropdown menus and their default values.\\
- `axis_options` - optional axis configuration. Supported keys are `:x_unit` (`:ms`/`:s`),
  `:xlabel`, `:ylabel`, `:xlimits`, `:ylimits`, `:xticks`, `:yticks`,
  `:xtickformat`, `:ytickformat`, `:xscale`, `:yscale`.\\

Action:\\
- Build AoG layers for lines and scatter, with optional faceting and scales.\\

**Return Value:** `Makie.GridLayoutSpec`.
"""
function update_grid(data, formula_values, cat_terms, continuous_terms, mapping_obs; axis_options = nothing)
    mapping_state = to_value(mapping_obs)

    if isnothing(data) || nrow(data) == 0
        empty_axis = S.Axis(; title = "No data for current selection")
        return S.GridLayout([(1, 1) => S.GridLayout([(1, 1) => empty_axis])])
    end

    # Use full-column checks to avoid transient first-row artifacts during rapid UI updates.
    cat_active = Dict(cat => any(data[!, cat] .!= "typical_value") for cat in cat_terms)
    cont_active =
        Dict(cont => any(data[!, cont] .!= "typical_value") for cont in continuous_terms)

    plot_data = copy(data)
    axis_config = Dict{Symbol,Any}(
        :x_unit => :ms,
        :xlabel => nothing,
        :ylabel => "Amplitude (uV)",
        :xlimits => nothing,
        :ylimits => nothing,
        :xticks => nothing,
        :yticks => nothing,
        :xtickformat => nothing,
        :ytickformat => nothing,
        :xscale => nothing,
        :yscale => nothing,
    )
    allowed_axis_keys = Set(keys(axis_config))
    if !isnothing(axis_options)
        for (k, v) in pairs(axis_options)
            if !(k in allowed_axis_keys)
                error(
                    "Unsupported axis option $(repr(k)). Supported keys: " *
                    join(sort!(collect(allowed_axis_keys)), ", "),
                )
            end
            axis_config[k] = v
        end
    end

    x_unit_raw = axis_config[:x_unit]
    x_unit = x_unit_raw isa AbstractString ? Symbol(lowercase(x_unit_raw)) : x_unit_raw
    if x_unit in (:ms, :millisecond, :milliseconds)
        plot_data[!, :time_axis] = 1000 .* plot_data.time
        default_xlabel = "Time (ms)"
    elseif x_unit in (:s, :sec, :second, :seconds)
        plot_data[!, :time_axis] = plot_data.time
        default_xlabel = "Time (s)"
    else
        error("Unsupported x_unit $(repr(x_unit_raw)). Supported values: :ms or :s.")
    end
    max_time = maximum(plot_data.time)
    plot_data[plot_data.time .≈ max_time, :yhat] .= NaN

    cat_color = get(cat_active, mapping_state[:color], false) ? mapping_state[:color] : nothing
    cat_marker = get(cat_active, mapping_state[:marker], false) ? mapping_state[:marker] : nothing
    cat_linestyle =
        get(cat_active, mapping_state[:linestyle], false) ? mapping_state[:linestyle] : nothing

    row_term =
        mapping_state[:row] != :none && get(cat_active, mapping_state[:row], false) ?
        mapping_state[:row] : :none
    col_term =
        mapping_state[:col] != :none && get(cat_active, mapping_state[:col], false) ?
        mapping_state[:col] : :none

    if cat_linestyle !== nothing && (cat_linestyle == row_term || cat_linestyle == col_term)
        # AoG currently behaves inconsistently when the same term drives both facetting and linestyle.
        # Prefer stable facets over redundant linestyle encoding in that case.
        cat_linestyle = nothing
    end

    formula_lookup = Dict(formula_values)
    function categorical_levels(term::Symbol)
        observed_levels = collect(unique(plot_data[!, term]))
        if !haskey(formula_lookup, term) || !(formula_lookup[term] isa AbstractSet)
            return observed_levels
        end
        if !get(cat_active, term, false)
            return observed_levels
        end
        configured_levels = sort!(collect(formula_lookup[term]))
        observed_set = Set(observed_levels)
        configured_observed = [lvl for lvl in configured_levels if lvl in observed_set]
        extra_levels = [lvl for lvl in observed_levels if !(lvl in configured_levels)]
        return vcat(configured_observed, extra_levels)
    end

    facet_aes = Dict{Symbol,Any}()
    if row_term != :none
        facet_aes[:row] = row_term
    end
    if col_term != :none
        facet_aes[:col] = col_term
    end

    scatter_aes = Dict{Symbol,Any}()
    if cat_color !== nothing
        scatter_aes[:color] = cat_color => string(cat_color)
    end
    if cat_marker !== nothing
        scatter_aes[:marker] = cat_marker => string(cat_marker)
    end

    line_aes = Dict{Symbol,Any}()
    if cat_linestyle !== nothing
        line_aes[:linestyle] = cat_linestyle => string(cat_linestyle)
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
        line_aes[:color] = cat_color => string(cat_color)
    end

    base = AlgebraOfGraphics.data(plot_data) *
           AlgebraOfGraphics.mapping(:time_axis, :yhat; pairs(facet_aes)...)

    default_color = RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0)
    scatter_visual_kwargs = Pair{Symbol,Any}[]
    line_visual_kwargs = Pair{Symbol,Any}[]
    if cat_color === nothing && !has_cont
        push!(scatter_visual_kwargs, :color => default_color)
        push!(line_visual_kwargs, :color => default_color)
    end
    if cat_linestyle === nothing
        # Force a stable default so stale linestyle mappings are not carried across rerenders.
        push!(line_visual_kwargs, :linestyle => :solid)
    end

    scatter_layer = AlgebraOfGraphics.mapping(; pairs(scatter_aes)...) *
                    AlgebraOfGraphics.visual(Scatter; markersize = 10, scatter_visual_kwargs...)
    line_layer = AlgebraOfGraphics.mapping(; pairs(line_aes)...) *
                 AlgebraOfGraphics.visual(Lines; line_visual_kwargs...)

    spec = base * (line_layer + scatter_layer)

    scales_kwargs = Dict{Symbol,Any}()
    if cat_color !== nothing
        scales_kwargs[:Color] =
            (; palette = Makie.wong_colors(), categories = categorical_levels(cat_color))
    end
    if cat_marker !== nothing
        scales_kwargs[:Marker] =
            (;
                palette = [:circle, :xcross, :star4, :diamond],
                categories = categorical_levels(cat_marker),
            )
    end
    if cat_linestyle !== nothing
        scales_kwargs[:LineStyle] =
            (;
                palette = [:solid, :dot, :dash],
                categories = categorical_levels(cat_linestyle),
            )
    end
    if row_term != :none
        scales_kwargs[:Row] = (; categories = categorical_levels(row_term))
    end
    if col_term != :none
        scales_kwargs[:Col] = (; categories = categorical_levels(col_term))
    end
    if has_cont
        cont_term = first(active_cont)
        scale_key = cat_color !== nothing ? :color2 : :Color
        scales_kwargs[scale_key] =
            (; colormap = :viridis, colorrange = extrema(data[!, cont_term]))
    end

    axis_kwargs = Dict{Symbol,Any}()
    axis_kwargs[:xlabel] = isnothing(axis_config[:xlabel]) ? default_xlabel : axis_config[:xlabel]
    axis_kwargs[:ylabel] = axis_config[:ylabel]
    for key in (:xlimits, :ylimits, :xticks, :yticks, :xtickformat, :ytickformat, :xscale, :yscale)
        if !isnothing(axis_config[key])
            axis_kwargs[key] = axis_config[key]
        end
    end

    spec_layout = AlgebraOfGraphics.draw_to_spec(
        spec,
        AlgebraOfGraphics.scales(; pairs(scales_kwargs)...);
        facet = (;
            linkxaxes = :none,
            linkyaxes = :none,
            hidexdecorations = false,
            hideydecorations = false,
        ),
        axis = (; pairs(axis_kwargs)...),
    )

    return S.GridLayout([(1, 1) => spec_layout])
end
