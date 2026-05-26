"""
    build_benchmark_fixture(config)

Generate synthetic EEG data, fit the default model, and return
`(model, positions_sets)` for harness modes.
"""
function build_benchmark_fixture(config::HarnessConfig)
    dataS, evts, _positions = build_synthetic_erp_data()
    formulaS = @formula(0 ~ 1 + luminance + fruit + animal)

    times = range(0, length = size(dataS, 2), step = 1 / config.sfreq)
    model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)

    _, topo_example_positions = TopoPlots.example_data()
    half_positions = topo_example_positions[1:2:end]

    positions_sets = Dict(
        "TopoPlots example" => topo_example_positions,
        "TopoPlots example (half)" => half_positions,
    )

    return model, positions_sets
end
