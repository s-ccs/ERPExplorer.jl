
"""
    update_grid(data, formula_values, categorical_vars, continuous_terms, mapping_obs)
Plot and update the interactive dashboard using AlgebraOfGraphics.

Arguments:\\
- `data::DataFrame` - the result of `effects(Dict(...), model)` with columns: yhat, channel, dummy, time, eventname and unique columns for each formula term.\\
- `formula_values::Vector{Pair{Symbol}}` - value range for continuous variables, levels for categorical.\\
- `categorical_vars::Vector{Symbol}` - categorical terms.\\
- `continuous_terms::Vector{Symbol}` - continuous terms.\\
- `mapping::Dict{Symbol, Symbol}` - dictionary with dropdown menus and their default values.\\
- `active_terms` - optional set/dict of formula terms active in the current effects call.\\
- `plot_size` - optional main plot size used to scale scatter markers and line widths.\\
- `axis_options` - optional axis configuration. Supported keys are `:x_unit` (`:ms`/`:s`),
  `:xlabel`, `:ylabel`, `:xlimits`, `:ylimits`, `:xticks`, `:yticks`,
  `:xtickformat`, `:ytickformat`, `:xscale`, `:yscale`.\\

Action:\\
- Build AoG layers for lines and scatter, with optional faceting and scales.\\

**Return Value:** `Makie.GridLayoutSpec`.
"""
function plot_area_scale(plot_size; base_size = (700, 600), facet_count = 1)
    length(plot_size) == 2 || throw(ArgumentError("plot_size must have width and height"))
    width, height = Float64(plot_size[1]), Float64(plot_size[2])
    base_width, base_height = Float64(base_size[1]), Float64(base_size[2])
    width > 0 && height > 0 || throw(ArgumentError("plot_size values must be positive"))
    base_width > 0 && base_height > 0 ||
        throw(ArgumentError("base_size values must be positive"))
    facet_count > 0 || throw(ArgumentError("facet_count must be positive"))

    effective_area = (width * height) / facet_count
    return sqrt(effective_area / (base_width * base_height))
end

function scaled_plot_markersize(
    plot_size;
    base_size = (700, 600),
    base_markersize = 10.0,
    min_markersize = 4.0,
    max_markersize = 24.0,
    facet_count = 1,
)
    scale = plot_area_scale(plot_size; base_size = base_size, facet_count = facet_count)
    return clamp(base_markersize * scale, min_markersize, max_markersize)
end

function scaled_plot_linewidth(
    plot_size;
    base_size = (700, 600),
    base_linewidth = 1.5,
    min_linewidth = 0.75,
    max_linewidth = 4.0,
    facet_count = 1,
)
    scale = plot_area_scale(plot_size; base_size = base_size, facet_count = facet_count)
    return clamp(base_linewidth * scale, min_linewidth, max_linewidth)
end

function floor_sigdigits(x; digits = 3)
    digits > 0 || throw(ArgumentError("digits must be positive"))
    value = Float64(x)
    isfinite(value) || return value
    value == 0 && return 0.0

    magnitude = floor(Int, log10(abs(value)))
    scale = 10.0^(digits - 1 - magnitude)
    return floor(value * scale) / scale
end

function format_sigdigits_down(x; digits = 3)
    value = floor_sigdigits(x; digits = digits)
    isfinite(value) || return string(value)
    value == 0 && return "0"

    decimals = max(0, digits - 1 - floor(Int, log10(abs(value))))
    label = fixed_decimal_string(value, decimals)
    if occursin(".", label)
        label = replace(label, r"0+$" => "")
        label = replace(label, r"\.$" => "")
    end
    return label
end

function fixed_decimal_string(value, decimals::Integer)
    decimals >= 0 || throw(ArgumentError("decimals must be non-negative"))
    if decimals == 0
        return string(round(Int, value))
    end

    scale = 10^decimals
    scaled = round(Int, abs(value) * scale)
    int_part, frac_part = divrem(scaled, scale)
    sign = signbit(value) ? "-" : ""
    return sign * string(int_part) * "." * lpad(string(frac_part), decimals, '0')
end

function nonsingular_colorbar_range(colorrange)
    lo, hi = colorrange
    if lo == hi
        if lo == 0
            return (lo, oneunit(lo))
        elseif lo < 0
            return (lo, false * lo)
        else
            return (false * lo, lo)
        end
    end
    return (lo, hi)
end

function continuous_colorbar_ticks(colorrange; tick_count = 5, digits = 3)
    tick_count >= 2 || throw(ArgumentError("tick_count must be at least 2"))
    lo, hi = nonsingular_colorbar_range(colorrange)
    tick_positions = collect(range(lo, hi; length = tick_count))
    return (
        tick_positions,
        [format_sigdigits_down(position; digits = digits) for position in tick_positions],
    )
end

function apply_continuous_colorbar_ticks!(spec_layout, colorrange)
    ticks = continuous_colorbar_ticks(colorrange)
    set_continuous_colorbar_ticks!(spec_layout, ticks)
    return spec_layout
end

function set_continuous_colorbar_ticks!(spec_layout::Makie.GridLayoutSpec, ticks::Tuple)
    for (_position, child) in spec_layout.content
        set_continuous_colorbar_ticks!(child, ticks)
    end
    return spec_layout
end

function set_continuous_colorbar_ticks!(spec::Makie.BlockSpec, ticks::Tuple)
    if spec.type == :Colorbar
        spec.kwargs[:ticks] = ticks
    end
    return spec
end

set_continuous_colorbar_ticks!(spec, ticks::Tuple) = spec

function update_grid(
    data,
    formula_values,
    cat_terms,
    continuous_terms,
    mapping_obs;
    axis_options = nothing,
    active_terms = nothing,
    plot_size = nothing,
)
    data, active_terms = unpack_erp_payload(data, active_terms)

    # `mapping_obs` can be either an Observable or a plain Dict.
    # `to_value` normalizes this so all later logic works on concrete values.
    mapping_state = to_value(mapping_obs)

    # Guard against empty/initial states (e.g. before first model response).
    # Returning a valid layout keeps the app render pipeline stable.
    if isnothing(data) || nrow(data) == 0
        empty_axis = S.Axis(; title = "No data for current selection")
        return S.GridLayout([(1, 1) => S.GridLayout([(1, 1) => empty_axis])])
    end

    data_cols = Set(Symbol.(names(data)))
    active_set = active_term_set(active_terms, data_cols, vcat(cat_terms, continuous_terms))
    cat_active = Dict(cat => cat in active_set && cat in data_cols for cat in cat_terms)
    cont_active =
        Dict(cont => cont in active_set && cont in data_cols for cont in continuous_terms)

    # Work on a local copy so we can add transformed plotting columns (`time_axis`) and
    # apply plotting-only tweaks without mutating upstream data.
    plot_data = copy(data)

    # Central axis configuration with defaults.
    # User-supplied `axis_options` only overrides keys explicitly provided.
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

    # Validate overrides early so mis-typed keys fail with a clear message.
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

    # Normalize x-axis unit and build the plotting x column.
    # We keep model `time` in seconds in the source data but default to milliseconds for display.
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

    # Break the last segment by inserting NaN at the maximal time point.
    # This avoids an unwanted "wrap-like" visual connection across grouped trajectories.
    max_time = maximum(plot_data.time)
    plot_data[plot_data.time .≈ max_time, :yhat] .= NaN

    # Resolve currently selected categorical aesthetic terms.
    # If a selected term is inactive, we treat the channel as "no mapping" (`nothing`).
    cat_color = get(cat_active, mapping_state[:color], false) ? mapping_state[:color] : nothing
    cat_marker = get(cat_active, mapping_state[:marker], false) ? mapping_state[:marker] : nothing
    cat_linestyle =
        get(cat_active, mapping_state[:linestyle], false) ? mapping_state[:linestyle] :
        nothing

    # Resolve facet terms (row/col), but only keep them when selected and active.
    row_term =
        mapping_state[:row] != :none && get(cat_active, mapping_state[:row], false) ?
        mapping_state[:row] : :none
    col_term =
        mapping_state[:col] != :none && get(cat_active, mapping_state[:col], false) ?
        mapping_state[:col] : :none

    # Known AoG edge case:
    # using the same term for linestyle and facet (row/col) can produce unstable layouts/legends.
    # Current policy: prioritize stable facetting and disable redundant linestyle in that case.
    if cat_linestyle !== nothing && (cat_linestyle == row_term || cat_linestyle == col_term)
        cat_linestyle = nothing
    end

    # Helper for deterministic category order:
    # 1) keep configured formula order when available,
    # 2) drop configured levels not present in current data slice,
    # 3) append any extra observed levels to avoid losing unexpected categories.
    formula_lookup = Dict(formula_values)
    function categorical_levels(term::Symbol)
        observed_levels = collect(unique(plot_data[!, term]))
        if !haskey(formula_lookup, term) || !(formula_lookup[term] isa AbstractSet)
            return observed_levels
        end
        if !get(cat_active, term, false)
            return observed_levels
        end
        configured_levels = sort_values(formula_lookup[term])
        observed_set = Set(observed_levels)
        configured_observed = [lvl for lvl in configured_levels if lvl in observed_set]
        extra_levels = [lvl for lvl in observed_levels if !(lvl in configured_levels)]
        return vcat(configured_observed, extra_levels)
    end

    # Build optional facet aesthetics only when row/col facetting is active.
    facet_aes = Dict{Symbol,Any}()
    if row_term != :none
        facet_aes[:row] = row_term
    end
    if col_term != :none
        facet_aes[:col] = col_term
    end

    # Scatter aesthetics: categorical encodings mapped to named scales.
    # We use explicit labels (`string(term)`) so legends keep readable titles.
    scatter_aes = Dict{Symbol,Any}()
    if cat_color !== nothing
        scatter_aes[:color] = cat_color => string(cat_color)
    end
    if cat_marker !== nothing
        scatter_aes[:marker] = cat_marker => string(cat_marker)
    end

    # Line aesthetics: currently only categorical linestyle is mapped here.
    line_aes = Dict{Symbol,Any}()
    if cat_linestyle !== nothing
        line_aes[:linestyle] = cat_linestyle => string(cat_linestyle)
    end

    # Continuous terms:
    # if one is active, color lines by that continuous term.
    # when categorical color is also active, use an alternate scale name (`:color2`) so both
    # categorical and continuous color encodings can coexist without colliding.
    active_cont = filter(cont -> get(cont_active, cont, false), continuous_terms)
    has_cont = !isempty(active_cont)
    continuous_colorrange = nothing
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

    # Shared base mapping for all layers.
    # `:time_axis` already reflects selected unit (ms/s).
    base = AlgebraOfGraphics.data(plot_data) *
           AlgebraOfGraphics.mapping(:time_axis, :yhat; pairs(facet_aes)...)

    # Visual defaults:
    # - force black when no color encoding is active,
    # - force solid linestyle when linestyle encoding is inactive.
    # This prevents stale style state from previous renders from leaking into the new view.
    default_color = RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0)
    scatter_visual_kwargs = Pair{Symbol,Any}[]
    line_visual_kwargs = Pair{Symbol,Any}[]
    if cat_color === nothing && !has_cont
        push!(scatter_visual_kwargs, :color => default_color)
        push!(line_visual_kwargs, :color => default_color)
    end
    if cat_linestyle === nothing
        push!(line_visual_kwargs, :linestyle => :solid)
    end
    n_rows = row_term == :none ? 1 : length(categorical_levels(row_term))
    n_cols = col_term == :none ? 1 : length(categorical_levels(col_term))
    facet_count = max(1, n_rows * n_cols)
    plot_markersize =
        isnothing(plot_size) ? 10.0 :
        scaled_plot_markersize(plot_size; facet_count = facet_count)
    plot_linewidth =
        isnothing(plot_size) ? 1.5 :
        scaled_plot_linewidth(plot_size; facet_count = facet_count)
    push!(line_visual_kwargs, :linewidth => plot_linewidth)

    # Compose layers: line + scatter over the same x/y/facet base mapping.
    # Both layers share the same grouped data and only differ in visual channels.
    scatter_layer = AlgebraOfGraphics.mapping(; pairs(scatter_aes)...) *
                    AlgebraOfGraphics.visual(
                        Scatter;
                        markersize = plot_markersize,
                        legend = (; markersize = 10.0),
                        scatter_visual_kwargs...,
                    )
    line_layer = AlgebraOfGraphics.mapping(; pairs(line_aes)...) *
                 AlgebraOfGraphics.visual(
                     Lines;
                     legend = (; linewidth = 1.5),
                     line_visual_kwargs...,
                 )

    spec = base * (line_layer + scatter_layer)

    # Build scale configuration explicitly.
    # Explicit category lists stabilize legend/facet ordering across reactive updates.
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
        scales_kwargs[:LineStyle] = (;
            palette = [
                :solid,
                Makie.Linestyle(Float32[0, 1, 2]),
                Makie.Linestyle(Float32[0, 3, 6]),
            ],
            categories = categorical_levels(cat_linestyle),
        )
    end
    if row_term != :none
        scales_kwargs[:Row] = (; categories = categorical_levels(row_term))
    end
    if col_term != :none
        scales_kwargs[:Col] = (; categories = categorical_levels(col_term))
    end

    # Continuous color scale (viridis) uses current data range of the active continuous term.
    # Scale key depends on whether categorical color occupies the default `:Color` slot.
    if has_cont
        cont_term = first(active_cont)
        scale_key = cat_color !== nothing ? :color2 : :Color
        continuous_colorrange = extrema(plot_data[!, cont_term])
        scales_kwargs[scale_key] =
            (; colormap = :viridis, colorrange = continuous_colorrange)
    end

    # Translate validated axis config into kwargs consumed by AoG draw.
    # `xlabel` falls back to x-unit dependent default when not explicitly set.
    axis_kwargs = Dict{Symbol,Any}()
    axis_kwargs[:xlabel] = isnothing(axis_config[:xlabel]) ? default_xlabel : axis_config[:xlabel]
    axis_kwargs[:ylabel] = axis_config[:ylabel]
    for key in (:xlimits, :ylimits, :xticks, :yticks, :xtickformat, :ytickformat, :xscale, :yscale)
        if !isnothing(axis_config[key])
            axis_kwargs[key] = axis_config[key]
        end
    end

    # Materialize AoG specification into Makie SpecApi layout.
    # Facet links/decorations are currently fully independent and visible on each panel.
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
    if continuous_colorrange !== nothing
        apply_continuous_colorbar_ticks!(spec_layout, continuous_colorrange)
    end

    # Wrap generated content in a stable one-cell root layout expected by caller.
    return S.GridLayout([(1, 1) => spec_layout])
end

function unpack_erp_payload(data, active_terms)
    if data isa NamedTuple && haskey(data, :data)
        payload_active_terms = haskey(data, :active_terms) ? data.active_terms : nothing
        return data.data, isnothing(active_terms) ? payload_active_terms : active_terms
    end
    return data, active_terms
end

function active_term_set(active_terms, data_cols::Set{Symbol}, all_terms)
    if isnothing(active_terms)
        return Set(term for term in all_terms if term in data_cols)
    elseif active_terms isa AbstractDict
        return Set(Symbol(term) for (term, enabled) in active_terms if enabled)
    elseif active_terms isa AbstractSet
        return Set(Symbol(term) for term in active_terms)
    else
        return Set(Symbol(term) for term in active_terms)
    end
end
