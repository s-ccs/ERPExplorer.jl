const BSplineTerm = Base.get_extension(Unfold, :UnfoldBSplineKitExt).BSplineTerm


get_sym(t::InterceptTerm) = ""
get_sym(t::AbstractTerm) = t.sym
get_sym(t::BSplineTerm) = t.term.sym
get_sym(t::InteractionTerm) = ""
get_sym(t::FunctionTerm) = ""
get_values(t::InterceptTerm) = (;)
get_values(t::CategoricalTerm) = t.contrasts.levels
get_values(t::BSplineTerm) = get_values(t.term)
get_values(t::ContinuousTerm) = (; min = t.min, max = t.max, var = t.var, mean = t.mean)
get_values(t::InteractionTerm) = (;)

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
    types = [t.name.name for t in typeof.(ts)]
    vals = get_values.(ts)
    ix = in.(types, Ref([:BSplineTerm, :ContinuousTerm, :CategoricalTerm]))
    return symbols[ix] .=> zip(names[ix], symbols[ix], types[ix], vals[ix])
end
