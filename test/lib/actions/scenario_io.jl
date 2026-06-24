"""
    read_action_scenario(path)

Read an action scenario file where each non-empty, non-comment line is one action ID.

Format rules:
- lines starting with `#` are ignored,
- inline comments after `#` are stripped,
- blank lines are ignored,
- at least one action ID must remain after parsing.
"""
function read_action_scenario(path::AbstractString)
    isfile(path) || error("Action scenario file not found: $(path)")

    action_ids = String[]
    for raw_line in eachline(path)
        line = strip(split(raw_line, '#'; limit = 2)[1])
        isempty(line) && continue
        push!(action_ids, line)
    end

    isempty(action_ids) && error("No action IDs found in scenario file: $(path)")
    return action_ids
end

"""
    load_validated_scenario(path; required_scope, source_label="")

Read scenario file and validate action IDs against the code registry.

If `required_scope` is provided, every action must support that scope.
"""
function load_validated_scenario(
    path::AbstractString;
    required_scope::Union{Nothing,Symbol} = nothing,
    source_label::AbstractString = "",
)
    action_ids = read_action_scenario(path)
    label = isempty(source_label) ? path : source_label
    ensure_registered_action_ids(action_ids; required_scope = required_scope, source_label = label)
    return action_ids
end
