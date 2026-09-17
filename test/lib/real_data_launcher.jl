const LAUNCHER_SYNTHETIC_SOURCE = "__synthetic_benchmark__"

empty_to_nothing(value::AbstractString) = isempty(strip(value)) ? nothing : strip(value)

function discover_jld2_files(data_dir::AbstractString)
    dir = abspath(data_dir)
    isdir(dir) || error("Data directory does not exist: $(dir)")
    return sort!(
        [
            joinpath(dir, name) for name in readdir(dir) if
            endswith(lowercase(name), ".jld2")
        ],
    )
end

function launcher_sources(files)
    return vcat(
        [(label = "Synthetic benchmark model", value = LAUNCHER_SYNTHETIC_SOURCE, kind = :synthetic)],
        [
            (label = basename(file), value = file, kind = :jld2) for file in files
        ],
    )
end

is_synthetic_launcher_source(value) = value == LAUNCHER_SYNTHETIC_SOURCE

function load_real_data_fixture(config::HarnessConfig)
    result = ERPExplorer.load_unfold_jld2(
        config.data_file;
        model_key = empty_to_nothing(config.model_key),
        channel_labels_file = empty_to_nothing(config.channel_labels_file),
        montage = config.montage,
    )
    print_loader_warnings(result.warnings)
    return result.model, result.positions
end

function print_loader_warnings(warnings)
    for warning in warnings
        println("real-data warning: ", warning)
    end
end

function loader_warning_dom(warnings)
    isempty(warnings) && return DOM.div()
    return DOM.div(
        [DOM.div(warning) for warning in warnings]...;
        role = "status",
        style = "padding:8px 12px; font:14px system-ui; color:#78350f; background:#fef3c7;",
    )
end

function query_value(params, key, default = "")
    return get(params, key, default)
end

function render_dashboard_from_model(session, request, model, positions)
    dashboard = ERPExplorer.explore(model; positions = positions)
    # Keep the launcher as the session owner. All dashboard callbacks belong to
    # this page and are disposed when navigation closes its connection.
    return Base.invokelatest(dashboard.handler, session, request)
end

function launcher_values(config::HarnessConfig, params = Dict{String,String}())
    return Dict(
        "data-file" => query_value(params, "data-file", LAUNCHER_SYNTHETIC_SOURCE),
        "model-key" => query_value(params, "model-key", config.model_key),
        "channel-labels-file" => query_value(params, "channel-labels-file", config.channel_labels_file),
        "montage" => query_value(params, "montage", config.montage),
    )
end

function launcher_input(label, name, input)
    return Row(
        DOM.label(label; var"for" = name, style = Styles("width" => "9rem", "font-weight" => "600")),
        input;
        align_items = "center",
        gap = "8px",
    )
end

function launcher_form(files, config::HarnessConfig;
    values = launcher_values(config), error_message = "")
    sources = launcher_sources(files)
    select = DOM.select(
        [
            DOM.option(source.label; value = source.value,
                selected = source.value == values["data-file"]) for source in sources
        ]...;
        name = "data-file",
        id = "data-file",
        class = "border rounded px-2 py-1",
        style = Styles("width" => "28rem"),
    )
    model_key = DOM.input(;
        type = "text",
        name = "model-key",
        id = "model-key",
        value = values["model-key"],
        class = "border rounded px-2 py-1",
        style = Styles("width" => "28rem"),
    )
    channel_labels = DOM.input(;
        type = "text",
        name = "channel-labels-file",
        id = "channel-labels-file",
        value = values["channel-labels-file"],
        class = "border rounded px-2 py-1",
        style = Styles("width" => "28rem"),
    )
    montage = DOM.input(;
        type = "text",
        name = "montage",
        id = "montage",
        value = values["montage"],
        class = "border rounded px-2 py-1",
        style = Styles("width" => "28rem"),
    )
    error_dom = isempty(error_message) ? DOM.div() : DOM.div(
        error_message;
        role = "alert",
        class = "px-3 py-2 text-sm text-red-900 bg-red-100",
    )

    form = DOM.form(
        Col(
            DOM.div("Load ERPExplorer data source"; class = "text-lg font-semibold"),
            launcher_input("Dataset", "data-file", select),
            launcher_input("Model key", "model-key", model_key),
            launcher_input("Channel labels", "channel-labels-file", channel_labels),
            launcher_input("Montage", "montage", montage),
            DOM.button(
                "Load";
                type = "submit",
                class = "bg-slate-800 text-white rounded px-3 py-2",
                style = Styles("width" => "8rem"),
            );
            gap = "10px",
        );
        method = "get",
        action = "/",
    )

    return DOM.div(
        Bonito.TailwindCSS,
        Card(
            Col(form, error_dom; gap = "10px");
            style = Styles("max-width" => "760px", "margin" => "24px auto"),
        ),
    )
end

function launcher_navigation(values)
    data_file = values["data-file"]
    label = is_synthetic_launcher_source(data_file) ? "Synthetic benchmark model" : basename(data_file)
    # A normal page navigation starts a fresh Bonito session for each dataset.
    # Hidden form fields preserve options and let the browser encode paths safely.
    return DOM.div(
        DOM.div("Dataset: ", DOM.strong(label; var"data-testid" = "loaded-dataset");
            style = "min-width:0; overflow-wrap:anywhere;"),
        DOM.form(
            [DOM.input(; type = "hidden", name = key, value = value)
                for (key, value) in sort!(collect(values))]...,
            DOM.button("Change dataset"; type = "submit", name = "select-data", value = "1",
                style = "padding:8px 12px; border:1px solid #cbd5e1; border-radius:6px; background:white; color:#0f172a; font:inherit; cursor:pointer; white-space:nowrap;");
            method = "get", action = "/", style = "margin:0;",
        );
        style = "display:flex; align-items:center; justify-content:space-between; gap:16px; padding:10px 16px; background:#f1f5f9; color:#0f172a; font:14px system-ui;",
    )
end

function build_real_data_launcher_app(config::HarnessConfig)
    discover_jld2_files(config.data_dir) # Validate the directory before starting the server.

    return App() do session, request
        params = Bonito.HTTP.queryparams(request)
        values = launcher_values(config, params)
        data_file = values["data-file"]
        if isempty(query_value(params, "data-file")) || query_value(params, "select-data") == "1"
            return launcher_form(discover_jld2_files(config.data_dir), config; values)
        end

        try
            result = if is_synthetic_launcher_source(data_file)
                model, positions = build_benchmark_fixture(config)
                (; model, positions, warnings = String[])
            else
                ERPExplorer.load_unfold_jld2(
                    data_file;
                    model_key = empty_to_nothing(values["model-key"]),
                    channel_labels_file = empty_to_nothing(values["channel-labels-file"]),
                    montage = values["montage"],
                )
            end
            print_loader_warnings(result.warnings)
            return DOM.div(
                launcher_navigation(values),
                loader_warning_dom(result.warnings),
                render_dashboard_from_model(session, request, result.model, result.positions),
            )
        catch err
            return launcher_form(
                discover_jld2_files(config.data_dir),
                config;
                values,
                error_message = "Load failed: $(sprint(showerror, err))",
            )
        end
    end
end
