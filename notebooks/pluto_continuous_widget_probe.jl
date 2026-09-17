### A Pluto.jl notebook ###
# v0.20.17

using Markdown
using InteractiveUtils

# ╔═╡ 5fe036b3-386e-4d16-9333-f8369236e6ef
md"""
# ERPExplorer continuous widget probe

This notebook isolates the continuous predictor widget used by `ERPExplorer.explore`.

Use it to tell whether the Pluto problem is:

- the raw `RangeSlider`,
- the package dropdown wrapper/CSS,
- or the full dashboard layout.
"""

# ╔═╡ b0f49111-0c6d-4d50-9009-5a672cd3ff3d
begin
	using Pkg

	repo_root = normpath(joinpath(@__DIR__, ".."))
	probe_env = joinpath(tempdir(), "ERPExplorerPlutoContinuousProbe")

	mkpath(probe_env)
	Pkg.activate(probe_env)
	Pkg.develop(path = repo_root)
	Pkg.add(["Bonito", "Unfold", "UnfoldSim"])
	Pkg.instantiate()

	using Bonito
	using ERPExplorer
	using Unfold
	using UnfoldSim
end

# ╔═╡ 4d769d7d-27f2-4d53-a00a-fd1350966bd3
begin
	data, evts = UnfoldSim.predef_eeg(; return_epoched = true)
	times = range(0, 1; length = size(data, 1))
	m = fit(UnfoldModel, @formula(0 ~ 1 + continuous + condition), evts, data, times)
	variables = ERPExplorer.extract_variables(m)
end

# ╔═╡ ed0f35db-c5e2-42af-9e26-5f95e94cd53c
md"""
## Extracted terms
"""

# ╔═╡ 1292c20b-dae2-4d09-b723-7f51e02e78f8
variables

# ╔═╡ f58e89d2-4b9c-492b-a49a-5ed0fd9d1392
md"""
## Raw continuous range slider

If this is visible and usable, the underlying `RangeSlider` works in Pluto.
"""

# ╔═╡ 690b8b95-9207-4dc7-a60e-8d6d5dd0bba3
begin
	continuous_term = first(filter(kv -> kv.first == :continuous, variables))
	continuous_range = ERPExplorer.value_range(continuous_term.second)
	App() do session
		ERPExplorer.widget(continuous_range)
	end
end

# ╔═╡ f9f2c11d-783f-4f0d-985c-560f5500e9e4
md"""
## Continuous widget inside ERPExplorer dropdown wrapper

This uses the same hover dropdown structure as the formula row.
"""

# ╔═╡ 34887d6b-47d3-4ec3-9c78-31633209f41c
begin
	css = Asset(joinpath(repo_root, "style.css"))
	wrapped_slider = ERPExplorer.widget(continuous_range)
	App() do session
		DOM.div(css, ERPExplorer.dropdown(:continuous, wrapped_slider); class = "erp-explorer", style = "height: 260px;")
	end
end

# ╔═╡ 63255d1e-c0c9-4b04-88ef-b7bcd7a92954
md"""
## Full formula widget row

If the raw slider works but this row shows an empty `continuous` dropdown, the likely culprit is the dropdown wrapper/CSS interaction in Pluto.
"""

# ╔═╡ d9999aae-11bf-4ee4-b67d-96554ffc59a9
begin
	_formula_defaults, _formula_toggle, formula_dom, _formula_values = ERPExplorer.formular_widgets(variables)
	App() do session
		DOM.div(Asset(joinpath(repo_root, "style.css")), formula_dom; class = "erp-explorer", style = "height: 280px;")
	end
end

# ╔═╡ Cell order:
# ╟─5fe036b3-386e-4d16-9333-f8369236e6ef
# ╠═b0f49111-0c6d-4d50-9009-5a672cd3ff3d
# ╠═4d769d7d-27f2-4d53-a00a-fd1350966bd3
# ╟─ed0f35db-c5e2-42af-9e26-5f95e94cd53c
# ╠═1292c20b-dae2-4d09-b723-7f51e02e78f8
# ╟─f58e89d2-4b9c-492b-a49a-5ed0fd9d1392
# ╠═690b8b95-9207-4dc7-a60e-8d6d5dd0bba3
# ╟─f9f2c11d-783f-4f0d-985c-560f5500e9e4
# ╠═34887d6b-47d3-4ec3-9c78-31633209f41c
# ╟─63255d1e-c0c9-4b04-88ef-b7bcd7a92954
# ╠═d9999aae-11bf-4ee4-b67d-96554ffc59a9
