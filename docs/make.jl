using ERPExplorer
using Documenter
using DocStringExtensions

# preload once

using CairoMakie
const Makie = CairoMakie # - for references
using Unfold
using DataFrames
using DataFramesMeta
using Literate
using Glob

GENERATED = joinpath(@__DIR__, "src", "generated")
SOURCE = joinpath(@__DIR__, "literate")
for subfolder ∈ ["intro"] #["how_to", "intro", "tutorials", "explanations"]
    local SOURCE_FILES = Glob.glob(subfolder * "/*.jl", SOURCE)
    foreach(fn -> Literate.markdown(fn, GENERATED * "/" * subfolder), SOURCE_FILES)
end

DocMeta.setdocmeta!(ERPExplorer, :DocTestSetup, :(using ERPExplorer); recursive = true)

makedocs(;
    modules = [ERPExplorer],
    authors = "Vladimir Mikheev, Simon Danisch, Benedikt Ehinger",
    repo = Documenter.Remotes.GitHub("s-ccs", "ERPExplorer.jl"),
    sitename = "ERPExplorer.jl",
    warnonly = :cross_references,
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://s-css.github.io/ERPExplorer.jl",
        assets = String[],
    ),
    pages = [
        "ERPExplorer highlights" => "index.md",
        #"Plotting" => "generated/intro/toposeries.md",
        #"Diagnostics" => "generated/intro/gnostics.md",
        #"API / DocStrings" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/s-ccs/ERPExplorer.jl",
    devbranch = "main",
    versions = "v#.#",
    push_preview = true,
)
