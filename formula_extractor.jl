function formula_extractor(m::UnfoldModel)
    f =  Unfold.formula(m)

    len = length(f.rhs.terms)
    #coefnames
    a = unique(f.rhs.terms)
    a = a[2:length(a)]
    name = []
    for i in a
        j = string(i)
        if occursin("spl", j) == false
            push!(name, split(j, "(")[1]) 
        else
            push!(name, j)
        end
    end
    
    # type
    ty = []
    for i in 2:len
        push!(ty, typeof.(f.rhs.terms)[i].name.name)
    end
    
    #terms
    te = []
    for i in 2:length(ty) + 1
        tmp = Nothing
        try
            tmp = f.rhs.terms[i].contrasts.levels
        catch
            tmp = f.rhs.terms[i]
            try
                tmp = (min = tmp.min, max = tmp.max, var = tmp.var, mean = tmp.mean) # round(tmp.mean, digits =2))
            catch
                tmp = tmp.term
                tmp = (min = tmp.min, max = tmp.max, var = tmp.var, mean = tmp.mean) 
            end
        end
        push!(te, tmp)
    end
    dnames = vcat(StatsModels.termvars.(first(values(design(m)))[1].rhs)...)

    d = Dict(dnames .=> zip(name, dnames, ty, te))    
    return d
end