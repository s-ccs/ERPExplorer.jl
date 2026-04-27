using UnfoldSim, DataFrames, Random
using GeometryBasics
function gen_data(n_channels = 64)
    d1, evts = UnfoldSim.predef_eeg(n_repeats = 120, noiselevel = 25; return_epoched = true)
    n_timepoints = size(d1, 1)

    # Generate distinct EEG signals per channel
    dataS = [
        d1 .+                                             # Keep ERP amplitude the same
        3 * sin.(0.1 * pi * i .+ rand() * 2π) .+          # Different slow oscillatory drift
        2 * sin.(0.3 * pi * i .* (1:n_timepoints)) .+     # Mid-frequency variation per channel
        randn(size(d1)) .* 5 .+                           # Add fine-grained channel-specific noise
        circshift(d1, rand(-10:10)) .* 0.2                # Random small time shift for variation
        for i = 1:n_channels
    ]
    dataS = permutedims(cat(dataS..., dims = 3), (3, 1, 2))
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
