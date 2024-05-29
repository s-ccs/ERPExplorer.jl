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

function extract_variables(model)
    ts = Unfold.formula(model).rhs.terms
    types = [t.name.name for t in typeof.(ts)]
    symbols = get_sym.(ts)
    names = string.(ts)
    vals = get_values.(ts)
    ix = in.(types, Ref([:BSplineTerm, :ContinuousTerm, :CategoricalTerm]))
    return symbols[ix] .=> zip(names[ix], symbols[ix], types[ix], vals[ix])
end
