const ALLOWED_VALUE_OPTIONS = Set([
    "mode",
    "bench-repeats",
    "bench-warmup",
    "bench-channel",
    "bench-out",
    "bench-live-start-delay",
    "bench-live-delay",
    "bench-live-timeout",
    "bench-live-actions",
    "bench-live-report",
])

const ALLOWED_FLAGS = Set([
    "bench",
    "help",
    "bench-live",
])

"""
    parse_cli_args(args)

Parse raw CLI tokens into `ParsedCliArgs`.

Accepted token styles:
- `--key=value` (stored in `options`)
- `--flag` or `-h` (stored in `flags`)
"""
function parse_cli_args(args::Vector{String})
    options = Dict{String,String}()
    flags = Set{String}()

    for token in args
        if token == "-h"
            push!(flags, "help")
            continue
        end

        startswith(token, "--") ||
            error("Unexpected positional argument $(repr(token)). Use --help for usage.")

        body = token[3:end]
        isempty(body) && error("Invalid empty option '--'.")

        split_body = split(body, "="; limit = 2)
        if length(split_body) == 2
            key, value = split_body
            isempty(key) && error("Invalid option $(repr(token)).")
            options[key] = value
        else
            push!(flags, split_body[1])
        end
    end

    return ParsedCliArgs(options, flags)
end

"""
    usage_text(script_path = "test/dashboard_options.jl")

Return user-facing CLI help text for the harness entrypoint.
"""
function usage_text(script_path::AbstractString = "test/dashboard_options.jl")
    return """
Usage:
  julia --project=. $(script_path) [--mode=<serve|bench|bench-live-auto>] [options]
  julia --project=. $(script_path) --bench

Modes:
  serve            Start interactive dashboard server (manual interaction).
  bench            Run offline benchmark actions and write CSV report.
  bench-live-auto  Start dashboard and automatically replay actions from a scenario file.

Flags:
  --bench          Alias for --mode=bench
  --help, -h       Show this help and exit

Options:
  --bench-repeats=<Int>           (default: $(DEFAULT_BENCH_REPEATS))
  --bench-warmup=<Int>            (default: $(DEFAULT_BENCH_WARMUP))
  --bench-channel=<Int>           (default: $(DEFAULT_BENCH_CHANNEL))
  --bench-out=<Path>              (default: timestamped report under test/reports)
  --bench-live-start-delay=<Sec>  (default: $(DEFAULT_LIVE_START_DELAY_SEC), after first render)
  --bench-live-delay=<Sec>        (default: $(DEFAULT_LIVE_STEP_DELAY_SEC), minimum enforced: 5)
  --bench-live-timeout=<Sec>      (default: $(DEFAULT_LIVE_ACTION_TIMEOUT_SEC))
  --bench-live-actions=<Path>     (default: test/livebench_actions_default.txt)
  --bench-live-report=<Path>      (default: timestamped report under test/reports)

Notes:
  Action IDs are defined in code registry under `test/lib/actions/`.
  Offline CSV columns:
    action_id,success,runs_completed,runs_requested,effects_median_ms,update_grid_median_ms,total_median_ms,error_message
  Live-auto CSV columns:
    sequence,event_source,action_id,effects_ms,plot_layout_ms,total_ms
"""
end

"""
    _parse_int(options, key, default; min_value)

Read an integer option and enforce a lower bound.
"""
function _parse_int(options::Dict{String,String}, key::String, default::Int; min_value::Int)
    raw = get(options, key, string(default))
    parsed = tryparse(Int, raw)
    isnothing(parsed) && error("Option --$(key) must be an integer, got $(repr(raw)).")
    parsed < min_value && error("Option --$(key) must be >= $(min_value), got $(parsed).")
    return parsed
end

"""
    _parse_float(options, key, default; min_value)

Read a floating-point option and enforce a lower bound.
"""
function _parse_float(
    options::Dict{String,String},
    key::String,
    default::Float64;
    min_value::Float64,
)
    raw = get(options, key, string(default))
    parsed = tryparse(Float64, raw)
    isnothing(parsed) && error("Option --$(key) must be numeric, got $(repr(raw)).")
    parsed < min_value && error("Option --$(key) must be >= $(min_value), got $(parsed).")
    return parsed
end

"""
    _validate_known_tokens(parsed)

Fail fast on unknown options and flags.
"""
function _validate_known_tokens(parsed::ParsedCliArgs)
    unknown_options = sort!(collect(setdiff(Set(keys(parsed.options)), ALLOWED_VALUE_OPTIONS)))
    isempty(unknown_options) ||
        error("Unknown option(s): $(join("--" .* unknown_options, ", ")). Use --help for usage.")

    unknown_flags = sort!(collect(setdiff(parsed.flags, ALLOWED_FLAGS)))
    isempty(unknown_flags) ||
        error("Unknown flag(s): $(join("--" .* unknown_flags, ", ")). Use --help for usage.")

    return nothing
end

"""
    _resolve_mode(parsed)

Resolve mode selection from parsed flags/options and validate conflicts.
"""
function _resolve_mode(parsed::ParsedCliArgs)
    mode_raw = get(parsed.options, "mode", "serve")

    if ("bench-live" in parsed.flags) || (mode_raw == "bench-live")
        error(
            "`bench-live` mode has been removed. Use `--mode=serve` for manual interaction or " *
            "`--mode=bench-live-auto` for scripted live benchmarking.",
        )
    end

    if mode_raw == "help" || ("help" in parsed.flags)
        return MODE_HELP
    end

    has_explicit_mode = haskey(parsed.options, "mode")
    bench_alias = "bench" in parsed.flags
    if bench_alias && has_explicit_mode && mode_raw != "bench"
        error(
            "Conflicting mode selection: --bench cannot be combined with --mode=$(repr(mode_raw)). " *
            "Use exactly one mode.",
        )
    end

    mode = if bench_alias || mode_raw == "bench"
        MODE_BENCH
    elseif mode_raw == "serve"
        MODE_SERVE
    elseif mode_raw == "bench-live-auto"
        MODE_BENCH_LIVE_AUTO
    else
        error(
            "Unsupported mode $(repr(mode_raw)). Supported modes: serve, bench, bench-live-auto.",
        )
    end

    return ensure_supported_mode(mode)
end

"""
    parse_harness_config(args; script_dir, host, port, sfreq)

Parse and validate CLI args into a `HarnessConfig`.

This function applies defaults, validates numeric ranges, resolves mode
selection rules, and computes default paths for reports and scenarios.
"""
function parse_harness_config(
    args::Vector{String};
    script_dir::AbstractString,
    host::AbstractString = DEFAULT_HOST,
    port::Int = DEFAULT_PORT,
    sfreq::Int = DEFAULT_SFREQ,
)
    parsed = parse_cli_args(args)
    _validate_known_tokens(parsed)

    mode = _resolve_mode(parsed)

    bench_repeats = _parse_int(parsed.options, "bench-repeats", DEFAULT_BENCH_REPEATS; min_value = 1)
    bench_warmup = _parse_int(parsed.options, "bench-warmup", DEFAULT_BENCH_WARMUP; min_value = 0)
    bench_channel = _parse_int(parsed.options, "bench-channel", DEFAULT_BENCH_CHANNEL; min_value = 1)

    live_start_delay_sec = _parse_float(
        parsed.options,
        "bench-live-start-delay",
        DEFAULT_LIVE_START_DELAY_SEC;
        min_value = 0.0,
    )
    live_delay_sec = _parse_float(
        parsed.options,
        "bench-live-delay",
        DEFAULT_LIVE_STEP_DELAY_SEC;
        min_value = 0.0,
    )
    live_action_timeout_sec = _parse_float(
        parsed.options,
        "bench-live-timeout",
        DEFAULT_LIVE_ACTION_TIMEOUT_SEC;
        min_value = 0.0,
    )
    live_action_timeout_sec <= 0.0 && error(
        "Option --bench-live-timeout must be > 0, got $(live_action_timeout_sec).",
    )

    default_live_actions_file = joinpath(script_dir, "livebench_actions_default.txt")
    default_reports_dir = joinpath(script_dir, "reports")

    return HarnessConfig(
        mode,
        String(host),
        port,
        sfreq,
        bench_repeats,
        bench_warmup,
        bench_channel,
        get(parsed.options, "bench-out", ""),
        live_start_delay_sec,
        max(5.0, live_delay_sec),
        live_action_timeout_sec,
        get(parsed.options, "bench-live-actions", default_live_actions_file),
        get(parsed.options, "bench-live-report", ""),
        default_reports_dir,
    )
end
