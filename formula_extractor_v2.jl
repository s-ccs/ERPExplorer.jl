"""
extracts symbol from continuous/spline terms
"""
		get_sym(t::InterceptTerm)= ""
		get_sym(t::AbstractTerm)= t.sym
		get_sym(t::Unfold.BSplineTerm) = t.term.sym
		get_sym(t::InteractionTerm) = ""
		get_sym(t::FunctionTerm) = ""
	

"""
extract values, min,max for continuous-types, levels for categorical
"""
	get_values(t::InterceptTerm) = (;)
	get_values(t::CategoricalTerm) = t.contrasts.levels
	get_values(t::Unfold.BSplineTerm) = get_values(t.term)
	get_values(t::ContinuousTerm) =   (;min = t.min, max = t.max, var = t.var, mean = t.mean)
	get_values(t::InteractionTerm) = (;)


"""
extracts formula into a Dict(:eventtablecolumn => ("stringname",:TermType,(valuesOrLabels))
"""
function formula_extractor(m)
ts = (Unfold.formula(m).rhs.terms)
types = [t.name.name for t in typeof.(ts)]
	
	symbols = get_sym.(ts)
	names = string.(ts)
	vals = get_values.(ts)
	ix = in.(types,Ref([:BSplineTerm,:ContinuousTerm,:CategoricalTerm]))
	d = Dict(symbols[ix].=>zip(names[ix],symbols[ix],types[ix],vals[ix]))
return d
end
