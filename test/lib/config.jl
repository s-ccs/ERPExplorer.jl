"""
    ParsedCliArgs

Raw command-line arguments split into:
- `options`: `--key=value` pairs
- `flags`: `--flag` style toggles
"""
struct ParsedCliArgs
    options::Dict{String,String}
    flags::Set{String}
end

"""
    HarnessConfig

Validated runtime configuration for the dashboard benchmark harness.

Fields:
- `mode`: selected runtime mode (`MODE_*` constant).
- `host`, `port`: server bind target for interactive modes.
- `sfreq`: sampling frequency used to construct model times.
- `bench_repeats`, `bench_warmup`, `bench_channel`: offline bench controls.
- `bench_out`: explicit offline CSV output path, empty means auto path.
- `live_start_delay_sec`, `live_step_delay_sec`, `live_action_timeout_sec`:
  auto-live playback timing.
- `live_actions_file`: scenario file consumed by live-auto mode.
- `live_report_file`: explicit live report CSV path, empty means auto path.
- `reports_dir`: default directory for auto-generated report paths.
"""
struct HarnessConfig
    mode::Symbol
    host::String
    port::Int
    sfreq::Int
    bench_repeats::Int
    bench_warmup::Int
    bench_channel::Int
    bench_out::String
    live_start_delay_sec::Float64
    live_step_delay_sec::Float64
    live_action_timeout_sec::Float64
    live_actions_file::String
    live_report_file::String
    reports_dir::String
end

"""Mode sentinel for help output (`--help` / `-h`)."""
const MODE_HELP = :help
"""Interactive dashboard mode (no benchmark automation)."""
const MODE_SERVE = :serve
"""Offline benchmark mode with CSV report output."""
const MODE_BENCH = :bench
"""Interactive app with scripted auto playback and timing report."""
const MODE_BENCH_LIVE_AUTO = :bench_live_auto
const SUPPORTED_MODES = Set([MODE_HELP, MODE_SERVE, MODE_BENCH, MODE_BENCH_LIVE_AUTO])

"""Default server host for interactive modes."""
const DEFAULT_HOST = "127.0.0.1"
"""Default server port for interactive modes."""
const DEFAULT_PORT = 8082
"""Default sampling frequency for fixture generation."""
const DEFAULT_SFREQ = 100
"""Default repeat count per offline benchmark action."""
const DEFAULT_BENCH_REPEATS = 5
"""Default warmup runs before collecting benchmark timings."""
const DEFAULT_BENCH_WARMUP = 1
"""Default channel used during offline benchmark effects filtering."""
const DEFAULT_BENCH_CHANNEL = 1
"""Default delay before live-auto playback starts."""
const DEFAULT_LIVE_START_DELAY_SEC = 20.0
"""Default delay between live-auto actions (minimum is enforced by CLI parser)."""
const DEFAULT_LIVE_STEP_DELAY_SEC = 5.0
"""Default debounce window before a live-auto render is treated as final."""
const DEFAULT_LIVE_RENDER_SETTLE_DELAY_SEC = 0.25
"""Default timeout for one render-triggering live-auto action."""
const DEFAULT_LIVE_ACTION_TIMEOUT_SEC = 60.0

"""
    ensure_supported_mode(mode)

Validate that `mode` is one of the supported harness modes and return it.
"""
function ensure_supported_mode(mode::Symbol)
    mode in SUPPORTED_MODES && return mode
    error("Unsupported mode $(repr(mode)).")
end
