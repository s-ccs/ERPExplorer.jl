using ERPExplorer, Bonito, Unfold, DataFrames, TopoPlots
include("../lib/regression_fixture.jl")
fixture = regression_fixture(; multievent = true)
app = App() do session, request
    params = Bonito.HTTP.queryparams(request)
    small = get(params, "small", "0") == "1"
    positions = get(params, "no_montage", "0") == "1" ? nothing : fixture.positions
    dashboard = ERPExplorer.build_dashboard(session, fixture.model; positions,
        size = small ? (600, 300) : (1100, 780), fit_window = !small)
    range_text = Observable("")
    on(session, dashboard.formula_toggle; update = true) do values
        pair = only(filter(p -> p.first == :luminance, values))
        range_text[] = join(pair.second[2], ",")
    end
    # Test observations stay in this fixture, outside the product's UI.
    observations = DOM.div(
        DOM.output(map(string, dashboard.channel_chosen); var"data-testid" = "state-channel"),
        DOM.output(map(string, dashboard.selected_event); var"data-testid" = "state-event"),
        DOM.output(range_text; var"data-testid" = "state-range"),
        DOM.output(map(string, dashboard.browser_ready); var"data-testid" = "state-ready"),
        DOM.output(map(x -> isnothing(x) ? "" : sprint(showerror, x), dashboard.render_error); var"data-testid" = "state-error");
        style = "display:none;")
    return DOM.div(
        DOM.style("body { background: rgb(17, 24, 39); color: rgb(240, 240, 240); margin: 0; }"),
        DOM.div(dashboard.dom; id = "notebook-cell", style = small ? "width: 600px; max-width:100%;" : "width:100%;"),
        observations,
    )
end
server = Bonito.Server(app, "127.0.0.1", parse(Int, get(ENV, "ERP_BROWSER_PORT", "8089")))
println("Browser regression fixture ready"); flush(stdout)
wait(Condition())
