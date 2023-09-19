using Unfold
get_sym(t::Unfold.AbstractTerm) = t.sym
get_sym(t::Unfold.BSplineTerm) = t.term.sym
get_sym(t::Unfold.InteractionTerm) = ""
get_sym(t::Unfold.FunctionTerm) = ""
get_values(t::Unfold.CategoricalTerm) = t.contrasts.levels
get_values(t::Unfold.BSplineTerm) = get_values(t.term)
get_values(t::Unfold.ContinuousTerm) = (; min=t.min, max=t.max, var=t.var, mean=t.mean)

function extract_variables(model)
    ts = Unfold.formula(model).rhs.terms
    types = [t.name.name for t in typeof.(ts)]
    symbols = get_sym.(ts)
    names = string.(ts)
    vals = get_values.(ts)
    ix = in.(types, Ref([:BSplineTerm, :ContinuousTerm, :CategoricalTerm]))
    return symbols[ix] .=> zip(names[ix], symbols[ix], types[ix], vals[ix])
end
