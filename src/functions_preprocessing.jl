term_type(t) = typeof(t).name.name

is_continuous_like(term_type::Symbol) = term_type in (:ContinuousTerm, :BSplineTerm)
is_supported_plot_term(term_type::Symbol) = term_type in (:CategoricalTerm, :ContinuousTerm, :BSplineTerm)
is_bspline_term(t) = term_type(t) == :BSplineTerm && hasproperty(t, :term)

get_sym(t::InterceptTerm) = ""
function get_sym(t::AbstractTerm)
    is_bspline_term(t) && return get_sym(getproperty(t, :term))
    return t.sym
end
get_sym(t::InteractionTerm) = ""
get_sym(t::FunctionTerm) = ""
function get_sym(t)
    is_bspline_term(t) && return get_sym(getproperty(t, :term))
    return ""
end

get_values(t::InterceptTerm) = (;)
get_values(t::CategoricalTerm) = t.contrasts.levels
get_values(t::ContinuousTerm) = (; min = t.min, max = t.max, var = t.var, mean = t.mean)
get_values(t::InteractionTerm) = (;)
get_values(t::FunctionTerm) = (;)
function get_values(t)
    is_bspline_term(t) && return get_values(getproperty(t, :term))
    return (;)
end

function formula_rhs_terms(rhs)
    terms = Any[]
    append_formula_rhs_terms!(terms, rhs)
    return terms
end

function append_formula_rhs_terms!(terms, term)
    if term isa Tuple
        for child in term
            append_formula_rhs_terms!(terms, child)
        end
    elseif is_supported_plot_term(term_type(term))
        push!(terms, term)
    elseif term isa InterceptTerm
        return nothing
    elseif hasproperty(term, :terms)
        for child in getproperty(term, :terms)
            append_formula_rhs_terms!(terms, child)
        end
    elseif hasproperty(term, :term)
        append_formula_rhs_terms!(terms, getproperty(term, :term))
    end
    return nothing
end

"""
    extract_variables(model)
Takes the Unfold model and extract variables from it for future functions. 

Arguments:\\
- `model::UnfoldLinearModel{Float64}` - Unfold linear model with categorical and continuous terms.

These variables are:\\
- `names` - all terms of the model.\\
- `symbols`- non-numeric terms of the model.\\
- `types` - types of terms.\\
- `vals` - min, max, variance, mean for continuous terms, levels for categorical terms.\\ 

**Return Values:** `Vector{Pair{Symbol}}`.
"""
function extract_variables(model)
    variables = Pair{Symbol,Any}[]
    seen = Dict{Symbol,Int}()

    for formula in Unfold.formulas(model)
        for term in formula_rhs_terms(formula.rhs)
            type = term_type(term)
            is_supported_plot_term(type) || continue

            symbol = get_sym(term)
            symbol isa Symbol || continue

            info = (string(term), symbol, type, get_values(term))
            if haskey(seen, symbol)
                index = seen[symbol]
                previous = variables[index].second
                previous[3] == type || throw(ArgumentError("Predictor $(symbol) has incompatible types across event formulas."))
                if type == :CategoricalTerm
                    Set(previous[4]) == Set(info[4]) || throw(ArgumentError(
                        "Predictor $(symbol) has different categorical levels across event formulas. ERPExplorer requires shared categorical predictors to have the same levels; explore these event models separately."))
                elseif type == :BSplineTerm
                    (previous[4].min, previous[4].max) == (info[4].min, info[4].max) || throw(ArgumentError(
                        "Spline predictor $(symbol) has different bounds across event formulas; explore these event models separately."))
                else
                    merged = merge(previous[4], (; min = min(previous[4].min, info[4].min), max = max(previous[4].max, info[4].max)))
                    variables[index] = symbol => (previous[1], symbol, type, merged)
                end
                continue
            end
            push!(variables, symbol => info)
            seen[symbol] = length(variables)
        end
    end

    return variables
end
