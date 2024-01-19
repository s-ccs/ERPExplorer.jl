function gen_data()
    d1, evts = UnfoldSim.predef_eeg(noiselevel=25; return_epoched=true)
    dataS = permutedims(repeat(d1, 1, 1, 64), (3, 1, 2))
    dataS = dataS .+ rand(dataS)

    evts = insertcols(evts,
        :continuous2 => rand(nrow(evts)),
        :continuous3 => rand(nrow(evts)),
        :continuous4 => rand(nrow(evts)),
        :continuous5 => rand(nrow(evts)), :condition2 => shuffle(repeat(["string1", "string2"], outer=div(nrow(evts), 2))),
        :condition3 => shuffle(repeat(["cat", "dog"], outer=div(nrow(evts), 2))),
        :condition4 => shuffle(repeat(["orange", "banana"], outer=div(nrow(evts), 2))),
        :condition5 => shuffle(repeat(["black", "white"], outer=div(nrow(evts), 2))))

    return dataS, evts
end

