"""
    load_unfold_jld2(path; model_key = nothing, channel_labels = nothing,
                     channel_labels_file = nothing, montage = "standard_1005")

Load a fitted `UnfoldModel` from a `.jld2` file and resolve optional channel
positions for ERPExplorer topoplots.

Returns a named tuple:
`(; model, positions, warnings)`.
"""
function load_unfold_jld2(
    path;
    model_key = nothing,
    channel_labels = nothing,
    channel_labels_file = nothing,
    montage = "standard_1005",
)
    file_path = abspath(string(path))
    isfile(file_path) || error("Unfold model file does not exist: $(file_path)")

    warnings = String[]
    objects = JLD2.load(file_path)
    model = load_unfold_model_from_objects(file_path, objects, model_key, warnings)

    labels, label_source = resolve_channel_labels(
        objects;
        channel_labels = channel_labels,
        channel_labels_file = channel_labels_file,
    )
    if !isnothing(labels) && length(labels) != model_channel_count(model)
        throw(ArgumentError("Expected $(model_channel_count(model)) channel labels in model order; got $(length(labels))."))
    end
    positions = resolve_channel_positions(labels, montage, warnings)
    if isnothing(labels)
        push!(
            warnings,
            "No channel labels found; loaded ERP model without topoplot positions.",
        )
    elseif isnothing(positions)
        push!(
            warnings,
            "Channel labels from $(label_source) could not be converted to $(montage) positions.",
        )
    end

    return (; model, positions, warnings)
end

function load_unfold_model_from_objects(file_path, objects, model_key, warnings)
    matches = find_unfold_models(objects)
    key = isnothing(model_key) ? nothing : string(model_key)
    if isnothing(key)
        isempty(matches) && error("No UnfoldModel found in $(file_path).")
        if length(matches) > 1
            push!(warnings, "Multiple UnfoldModel objects found; using $(matches[1].first). " *
                "Pass model_key to choose explicitly. Available keys: $(join(first.(matches), ", ")).")
        end
        key, model = first(matches)
    else
        selected = findall(pair -> pair.first == key, matches)
        length(selected) > 1 && throw(ArgumentError("Ambiguous model key $(repr(key)); use distinct container keys."))
        model = isempty(selected) ? JLD2.load(file_path, key) : matches[only(selected)].second
        model isa UnfoldModel || throw(ArgumentError("Object $(repr(key)) is not an UnfoldModel; got $(typeof(model))."))
    end

    # Unfold.save omits model matrices and Unfold.load also upgrades older fit objects.
    model = key == "uf" && haskey(objects, "uf") ? Unfold.load(file_path, UnfoldModel) : restore_model_matrices(model)
    isempty(Unfold.coef(model)) && throw(ArgumentError("The selected UnfoldModel is not fitted."))
    return model
end

function restore_model_matrices(model::UnfoldModel)
    matrices = Unfold.designmatrix(model)
    any(dm -> isempty(Unfold.modelmatrix(dm)), matrices) || return model
    forms = Unfold.formulas(model)
    events = Unfold.events(model)
    rebuilt = [typeof(dm)(form, StatsModels.modelcols(form.rhs, table), table)
               for (dm, form, table) in zip(matrices, forms, events)]
    return typeof(model)(Unfold.design(model), rebuilt, model.modelfit)
end

function model_channel_count(model::UnfoldModel)
    count = size(Unfold.coef(model), 1)
    count > 0 || throw(ArgumentError("The model has no fitted channels."))
    return count
end

function validate_channel_positions(positions, count)
    isnothing(positions) && return nothing
    if positions isa AbstractDict || positions isa NamedTuple
        isempty(positions) && throw(ArgumentError("positions must contain at least one position set"))
        foreach(p -> validate_channel_positions(p, count), values(positions))
        return positions
    end
    length(positions) == count || throw(ArgumentError("Expected $(count) channel positions in model order; got $(length(positions))."))
    all(p -> length(p) == 2 && all(isfinite, p), positions) ||
        throw(ArgumentError("Channel positions must be finite 2D coordinates."))
    return positions
end

function find_unfold_models(value, path = "\$")
    matches = Pair{String,Any}[]
    if value isa UnfoldModel
        push!(matches, path => value)
    elseif value isa AbstractDict
        for key in sort_values(collect(keys(value)))
            append!(matches, find_unfold_models(value[key], join_model_path(path, key)))
        end
    elseif value isa NamedTuple
        for key in sort_values(collect(keys(value)))
            append!(matches, find_unfold_models(getproperty(value, key), join_model_path(path, key)))
        end
    elseif value isa Tuple
        for (index, item) in enumerate(value)
            append!(matches, find_unfold_models(item, "$(path)[$(index)]"))
        end
    elseif value isa AbstractVector && length(value) <= 100 && !(eltype(value) <: Number)
        for (index, item) in enumerate(value)
            append!(matches, find_unfold_models(item, "$(path)[$(index)]"))
        end
    end
    return matches
end

join_model_path(parent, key) = parent == "\$" ? string(key) : "$(parent).$(key)"

function resolve_channel_labels(objects; channel_labels = nothing, channel_labels_file = nothing)
    if !isnothing(channel_labels)
        return normalize_channel_labels(channel_labels), "explicit channel_labels"
    end

    if !isnothing(channel_labels_file) && !isempty(strip(string(channel_labels_file)))
        labels = read_channel_labels_file(string(channel_labels_file))
        return labels, string(channel_labels_file)
    end

    labels = find_channel_labels_in_objects(objects)
    isnothing(labels) && return nothing, "none"
    return labels, "JLD2 file"
end

function normalize_channel_labels(values)
    labels = String[]
    for (index, value) in enumerate(values)
        (ismissing(value) || isnothing(value)) && throw(ArgumentError("Missing label for channel $(index); channel order must be preserved."))
        label = strip(string(value))
        isempty(label) && throw(ArgumentError("Blank label for channel $(index); channel order must be preserved."))
        push!(labels, label)
    end
    isempty(labels) && throw(ArgumentError("Channel label list is empty."))
    length(unique(lowercase.(labels))) == length(labels) || throw(ArgumentError("Channel labels must be unique (ignoring case)."))
    return labels
end

normalize_channel_labels(value::AbstractString) = normalize_channel_labels([value])
normalize_channel_labels(value::Symbol) = normalize_channel_labels([value])

function read_channel_labels_file(path::AbstractString)
    file_path = abspath(path)
    isfile(file_path) || error("Channel-label mapping file does not exist: $(file_path)")
    ext = lowercase(splitext(file_path)[2])
    delim = ext == ".tsv" ? '\t' : ','
    table = DataFrame(CSV.File(file_path; delim = delim))
    return channel_labels_from_table(table)
end

function channel_labels_from_table(table::AbstractDataFrame)
    ncol(table) > 0 || error("Channel-label mapping table has no columns.")
    names_lookup = Dict(lowercase(string(name)) => name for name in names(table))
    label_candidates = [
        "label",
        "labels",
        "channel_name",
        "channel_names",
        "ch_name",
        "ch_names",
        "name",
        "names",
        "channel",
        "channels",
    ]
    label_col = first_present_name(names_lookup, label_candidates)
    if isnothing(label_col)
        ncol(table) == 1 ||
            error("Channel-label mapping table needs a label/name column or exactly one column.")
        label_col = names(table)[1]
    end

    index_candidates = ["index", "idx", "channel_index", "channel_idx", "chan", "channel_number"]
    index_col = first_present_name(names_lookup, index_candidates)
    ordered = if isnothing(index_col)
        table
    else
        indices = map(table[!, index_col]) do value
            index = tryparse(Int, strip(string(value)))
            isnothing(index) && throw(ArgumentError("Channel indices must be integers from 1 to $(nrow(table))."))
            index
        end
        sort(indices) == collect(1:nrow(table)) ||
            throw(ArgumentError("Channel indices must contain each integer from 1 to $(nrow(table)) exactly once; missing or duplicate indices would change channel identity."))
        table[sortperm(indices), :]
    end
    return normalize_channel_labels(ordered[!, label_col])
end

function first_present_name(names_lookup, candidates)
    for candidate in candidates
        haskey(names_lookup, candidate) && return names_lookup[candidate]
    end
    return nothing
end

function find_channel_labels_in_objects(objects)
    candidates = Set([
        "channel_labels",
        "channel_label",
        "channel_names",
        "channel_name",
        "ch_names",
        "ch_name",
        "chanlabels",
        "chanlabel",
        "labels",
        "label",
        "channels",
        "channel",
        "chanlocs",
        "electrodes",
    ])

    if objects isa AbstractDict
        for key in sort_values(collect(keys(objects)))
            if lowercase(string(key)) in candidates
                labels = maybe_channel_labels(objects[key])
                isnothing(labels) || return labels
            end
        end
    elseif objects isa NamedTuple
        for key in sort_values(collect(keys(objects)))
            if lowercase(string(key)) in candidates
                labels = maybe_channel_labels(getproperty(objects, key))
                isnothing(labels) || return labels
            end
        end
    end
    return nothing
end

function maybe_channel_labels(value)
    if value isa AbstractDataFrame
        return channel_labels_from_table(value)
    elseif value isa AbstractVector
        all(label_like, value) && return normalize_channel_labels(value)
        labels = labels_from_struct_vector(value)
        isnothing(labels) || return labels
    elseif value isa AbstractDict
        labels = labels_from_keyed_container(value)
        isnothing(labels) || return labels
    elseif value isa NamedTuple
        labels = labels_from_keyed_container(value)
        isnothing(labels) || return labels
    end
    return nothing
end

label_like(value) = ismissing(value) || isnothing(value) || value isa AbstractString || value isa Symbol

function labels_from_struct_vector(values)
    labels = Any[]
    for value in values
        label = label_from_struct(value)
        isnothing(label) && return nothing
        push!(labels, label)
    end
    isempty(labels) && return nothing
    return normalize_channel_labels(labels)
end

function label_from_struct(value)
    for key in (:label, :labels, :channel, :channel_name, :ch_name, :name)
        if hasproperty(value, key)
            return getproperty(value, key)
        end
    end
    if value isa AbstractDict
        for key in ("label", "labels", "channel", "channel_name", "ch_name", "name")
            haskey(value, key) && return value[key]
            sym_key = Symbol(key)
            haskey(value, sym_key) && return value[sym_key]
        end
    end
    return nothing
end

function labels_from_keyed_container(container)
    for key in (:label, :labels, :channel, :channels, :channel_name, :channel_names, :ch_name, :ch_names, :name, :names)
        value = keyed_value(container, key)
        isnothing(value) || return normalize_channel_labels(value)
    end
    return nothing
end

function keyed_value(container, key::Symbol)
    if container isa NamedTuple && haskey(container, key)
        return getproperty(container, key)
    elseif container isa AbstractDict
        haskey(container, key) && return container[key]
        string_key = string(key)
        haskey(container, string_key) && return container[string_key]
    end
    return nothing
end

function resolve_channel_positions(labels, montage, warnings)
    isnothing(labels) && return nothing
    montage_name = lowercase(string(montage))
    if !(montage_name in ("standard_1005", "standard_10_05", "10_05", "1005"))
        push!(warnings, "Unsupported montage $(repr(montage)); only standard_1005 is supported.")
        return nothing
    end

    try
        return TopoPlots.labels2positions(labels)
    catch err
        push!(warnings, sprint(showerror, err))
        return nothing
    end
end
