using Random

"""Small deterministic fitted model shared by regression and browser tests."""
function regression_fixture(; multievent = false, different_levels = false, different_bounds = false)
    rng = MersenneTwister(31)
    n = 48
    times = collect(range(-0.05, 0.05; length = 11))
    luminance = repeat(collect(range(1000.0, 1001.0; length = 24)), 2)
    different_bounds && (luminance[25:end] .+= 100)
    fruit = repeat(["apple", "pear"], 24)
    different_levels && (fruit[25:end] = repeat(["cherry", "plum"], 12))
    events = DataFrame(; luminance, fruit, animal = shuffle(rng, repeat(["cat", "dog"], 24)),
        kind = repeat(["stimulus", "response"]; inner = 24), latency = 1:n)
    data = [0.2ch + sin(20time) + 2(events.luminance[e] - 1000) +
        (events.fruit[e] == "apple") + 0.01randn(rng)
        for ch in 1:4, time in times, e in 1:n]
    formula = @formula(0 ~ 1 + luminance + fruit + animal)
    model = if multievent
        fit(UnfoldModel, ["stimulus" => (formula, times), "response" => (formula, times)], events, data; eventcolumn = "kind")
    else
        fit(UnfoldModel, formula, events, data, times)
    end
    labels = ["Fp1", "Fp2", "C3", "C4"]
    return (; model, labels, positions = TopoPlots.labels2positions(labels), events, times, data)
end
