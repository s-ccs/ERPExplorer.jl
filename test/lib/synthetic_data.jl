import DataFrames
import GeometryBasics
import Random
import UnfoldSim

"""
    build_synthetic_erp_data(n_channels = 64)

Generate synthetic epoched EEG data used by tests, examples, and the dashboard
benchmark harness.
"""
function build_synthetic_erp_data(n_channels = 64)
    d1, evts = UnfoldSim.predef_eeg(n_repeats = 120, noiselevel = 25; return_epoched = true)
    n_timepoints = size(d1, 1)

    dataS = [
        d1 .+
        3 * sin.(0.1 * pi * i .+ Random.rand() * 2π) .+
        2 * sin.(0.3 * pi * i .* (1:n_timepoints)) .+
        Random.randn(size(d1)...) .* 5 .+
        circshift(d1, Random.rand(-10:10)) .* 0.2 for i = 1:n_channels
    ]
    dataS = permutedims(cat(dataS..., dims = 3), (3, 1, 2))
    dataS = dataS .+ Random.rand(size(dataS)...)

    n_events = DataFrames.nrow(evts)
    evts = DataFrames.insertcols(
        evts,
        :saccade_amplitude => Random.rand(n_events) .* 15,
        :luminance => Random.rand(n_events) .* 100,
        :contrast => Random.rand(n_events),
        :string => Random.shuffle(
            repeat(
                ["stringsuperlong", "stringshort", "stringUPPERCASE", "stringEXCITED!!!!"],
                outer = div(n_events, 4),
            ),
        ),
        :animal => Random.shuffle(repeat(["cat", "dog"], outer = div(n_events, 2))),
        :fruit => Random.shuffle(repeat(["orange", "banana"], outer = div(n_events, 2))),
        :color => Random.shuffle(repeat(["black", "white"], outer = div(n_events, 2))),
    )

    positions = Random.rand(GeometryBasics.Point2f, size(dataS, 1))
    return dataS, evts, positions
end
