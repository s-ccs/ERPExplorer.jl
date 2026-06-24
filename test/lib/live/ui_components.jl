"""
    build_mapping_controls(var_names, var_types)

Create mapping dropdown UI and control handles.
"""
function build_mapping_controls(var_names, var_types)
    categorical_terms = [term for (ix, term) in enumerate(var_names) if var_types[ix] == :CategoricalTerm]
    push!(categorical_terms, :none)

    color_dd = Dropdown(categorical_terms; index = length(categorical_terms))
    marker_dd = Dropdown(categorical_terms; index = length(categorical_terms))
    linestyle_dd = Dropdown(categorical_terms; index = length(categorical_terms))
    col_dd = Dropdown(categorical_terms; index = length(categorical_terms))
    row_dd = Dropdown(categorical_terms; index = length(categorical_terms))

    mapping = @lift Dict(
        :color => $(color_dd.value),
        :marker => $(marker_dd.value),
        :linestyle => $(linestyle_dd.value),
        :col => $(col_dd.value),
        :row => $(row_dd.value),
    )

    mapping_dom = Col(
        Row(DOM.div("color:"), color_dd, align_items = "center", justify_items = "end"),
        Row(DOM.div("marker:"), marker_dd, align_items = "center", justify_items = "end"),
        Row(DOM.div("linestyle:"), linestyle_dd, align_items = "center", justify_items = "end"),
        Row(DOM.div("column facet"), col_dd, align_items = "center", justify_items = "end"),
        Row(DOM.div("row facet"), row_dd, align_items = "center", justify_items = "end"),
    )

    controls = Dict(
        :color => color_dd,
        :marker => marker_dd,
        :linestyle => linestyle_dd,
        :col => col_dd,
        :row => row_dd,
    )

    return mapping, mapping_dom, controls
end

"""
    build_topoplot_panel(positions, channel_chosen; size)

Create topoplot panel for position sets or single position vectors.
"""
function build_topoplot_panel(positions, channel_chosen; size)
    if positions isa AbstractDict || positions isa NamedTuple
        pos_sets = Dict{String,Any}()
        for (key, value) in pairs(positions)
            pos_sets[string(key)] = value
        end
        pos_keys = collect(keys(pos_sets))
        isempty(pos_keys) &&
            throw(ArgumentError("positions must contain at least one position set"))
        topo_select = Dropdown(pos_keys; index = 1)

        topo_obs = Observable{Any}(
            ERPExplorer.topoplot_widget(pos_sets[pos_keys[1]], channel_chosen; size = size),
        )
        on(topo_select.value) do key
            channel_chosen[] = 1
            topo_obs[] = ERPExplorer.topoplot_widget(pos_sets[key], channel_chosen; size = size)
        end

        return Col(Row(DOM.div("Topoplot:"), topo_select, align_items = "center"), topo_obs)
    elseif isnothing(positions)
        return nothing
    else
        return ERPExplorer.topoplot_widget(positions, channel_chosen; size = size)
    end
end

"""
    reset_all_axes!(fig_ref, lock_ref)

Reset and auto-limit all Makie axes in the current figure.
"""
function reset_all_axes!(fig_ref, lock_ref)
    fig_obj = fig_ref[]
    isnothing(fig_obj) && return

    lock(lock_ref) do
        function collect_axes!(acc, item)
            if item isa Makie.Axis
                push!(acc, item)
            elseif item isa Makie.GridLayoutBase.GridLayout
                for child in Makie.GridLayoutBase.contents(item)
                    collect_axes!(acc, child)
                end
            end
        end

        axes = Makie.Axis[]
        collect_axes!(axes, fig_obj.figure.layout)
        foreach(ax -> (Makie.reset_limits!(ax); Makie.autolimits!(ax)), axes)
    end
end
