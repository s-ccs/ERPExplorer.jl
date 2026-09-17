@testset "Dataset launcher navigation" begin
    harness = DashboardBenchHarness
    mktempdir() do dir
        first_file = joinpath(dir, "first & model.jld2")
        JLD2.jldopen(first_file, "w") do file
            file["nested/model"] = "Not an Unfold model"
        end
        config = parse_harness_config([
            "--mode=serve", "--data-dir=$(dir)", "--model-key=default-model",
        ]; script_dir = @__DIR__)
        app = build_real_data_launcher_app(config)
        values = Dict(
            "data-file" => first_file,
            "model-key" => "nested/model",
            "channel-labels-file" => joinpath(dir, "channels & labels.tsv"),
            "montage" => "1005",
        )
        @test harness.launcher_values(config)["model-key"] == "default-model"
        @test harness.launcher_values(config, values) == values
        @test harness.launcher_values(config, Dict("model-key" => ""))["model-key"] == ""

        session = Bonito.Session(Bonito.NoConnection(); asset_server = Bonito.NoServer())
        html(dom) = replace(sprint(show, MIME"text/html"(), Bonito.jsrender(session, dom)), "&#38;" => "&amp;")
        request(params) = Bonito.HTTP.Request("GET", string(Bonito.HTTP.URI("/"; query = params)))
        try
            # Returning must not attempt to load the selected file (invalid here).
            return_request = request(merge(values, Dict("select-data" => "1")))
            selection = html(Base.invokelatest(app.handler, session, return_request))
            @test occursin("Load ERPExplorer data source", selection)
            @test !occursin("Load failed", selection)
            @test occursin("nested/model", selection)
            @test occursin("channels &amp; labels.tsv", selection)
            @test occursin(r"<option[^>]*selected[^>]*>first &amp; model.jld2</option>", selection)

            # Files added after startup become selectable on return.
            write(joinpath(dir, "second.jld2"), "invalid model")
            refreshed = html(Base.invokelatest(app.handler, session, return_request))
            @test occursin("second.jld2", refreshed)

            failure = html(Base.invokelatest(app.handler, session, request(values)))
            @test occursin("Load failed:", failure)
            @test occursin("is not an UnfoldModel", failure)
            @test occursin("nested/model", failure)
            @test occursin(r"<option[^>]*selected[^>]*>first &amp; model.jld2</option>", failure)

            navigation = html(harness.launcher_navigation(values))
            @test occursin("Change dataset", navigation)
            @test occursin("first &amp; model.jld2", navigation)
            @test occursin("channels &amp; labels.tsv", navigation)
            @test occursin("select-data", navigation)
        finally
            close(session)
        end
    end
end
