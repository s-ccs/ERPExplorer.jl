using UnfoldSim, DataFrames, Random
using GeometryBasics
function gen_data()
    d1, evts = UnfoldSim.predef_eeg(n_repeats = 120, noiselevel = 25; return_epoched = true)
    dataS = permutedims(repeat(d1, 1, 1, 64), (3, 1, 2))
    dataS = dataS .+ rand(dataS)

    evts = insertcols(
        evts,
        :saccade_amplitude => rand(nrow(evts)) .* 15,
        :luminance => rand(nrow(evts)) .* 100,
        :contrast => rand(nrow(evts)),
        :string => shuffle(
            repeat(
                ["stringsuperlong", "stringshort", "stringUPPERCASE", "stringEXCITED!!!!"],
                outer = div(nrow(evts), 4),
            ),
        ),
        :animal => shuffle(repeat(["cat", "dog"], outer = div(nrow(evts), 2))),
        :fruit => shuffle(repeat(["orange", "banana"], outer = div(nrow(evts), 2))),
        :color => shuffle(repeat(["black", "white"], outer = div(nrow(evts), 2))),
    )

    positions = rand(Point2f, size(dataS, 1))
    return dataS, evts, positions
end
