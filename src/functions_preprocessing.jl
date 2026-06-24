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
    ts = Unfold.formulas(model)[1].rhs.terms
    names = string.(ts)
    symbols = get_sym.(ts) # non-numeric model terms
    types = term_type.(ts)
    vals = get_values.(ts)
    return [
        symbol => (name, symbol, type, values) for
        (name, symbol, type, values) in zip(names, symbols, types, vals) if
        is_supported_plot_term(type)
    ]
end
