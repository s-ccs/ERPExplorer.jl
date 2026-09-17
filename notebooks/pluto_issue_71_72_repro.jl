### A Pluto.jl notebook ###
# v0.20.17

using Markdown
using InteractiveUtils

# ╔═╡ 9b8f9506-54de-4a81-a75b-7fca2fa7ad38
md"""
# ERPExplorer Pluto repro for issues #71 and #72

This notebook uses the local checkout of `ERPExplorer.jl`.

Expected checks:

- Issue #71: with `fit_window=false` and a small `size`, the dashboard should not be cut off.
- Issue #72: the `continuous` formula dropdown should show a usable range slider in Pluto.
"""

# ╔═╡ 5b9b0a72-6f22-4d5f-bef8-472ac7f021b3
begin
	using Pkg

	repo_root = normpath(joinpath(@__DIR__, ".."))
	repro_env = joinpath(tempdir(), "ERPExplorerPlutoIssue71_72")

	mkpath(repro_env)
	Pkg.activate(repro_env)
	Pkg.develop(path = repo_root)
	Pkg.add(["Unfold", "UnfoldSim"])
	Pkg.instantiate()

	using ERPExplorer
	using Unfold
	using UnfoldSim
end

# ╔═╡ f420ea7e-469c-4ef0-a914-4635da9fd0d0
md"""
## Build the model from issue #72
"""

# ╔═╡ 1729df66-ee97-44ef-a871-7c8b20e68534
begin
	data, evts = UnfoldSim.predef_eeg(; return_epoched = true)
	times = range(0, 1; length = size(data, 1))
	m = fit(UnfoldModel, @formula(0 ~ 1 + continuous + condition), evts, data, times)
end

# ╔═╡ f7c8fe21-4d23-4304-9496-a616d0d80768
md"""
## Data/model sanity checks
"""

# ╔═╡ 75c9658b-b730-4e0f-a3b3-98ea643074da
begin
	(size(data), names(evts), ERPExplorer.extract_variables(m))
end

# ╔═╡ 7a0b9bd7-96b0-4f3d-ae5a-55483d4d994a
md"""
## Issue #72 check

Hover or open the `continuous` entry in the formula row. In the issue, this dropdown is empty in Pluto.
"""

# ╔═╡ 0a2c368d-d7ea-4f04-b25c-e45a0809741f
ERPExplorer.explore(m; fit_window = false, size = (600, 300))

# ╔═╡ 5cae5e83-9248-4dc2-8e1d-99caf59abf82
md"""
## Issue #71 check

The next cell uses a larger explicit size with `fit_window=false`. The rendered dashboard should show the whole figure instead of cutting it off.
"""

# ╔═╡ 5b5ee6c2-4761-440d-8f0f-003bc5c874d8
ERPExplorer.explore(m; fit_window = false, size = (900, 600))

# ╔═╡ 9979cc23-21d3-4434-a0ef-d0d87de02e69
md"""
## Fit-to-window comparison

This is the current responsive mode, useful as a control against the fixed-size examples above.
"""

# ╔═╡ 707f015a-98bb-4a07-bc9a-83a5c0a3632a
ERPExplorer.explore(m; fit_window = true, size = (900, 600))

# ╔═╡ Cell order:
# ╟─9b8f9506-54de-4a81-a75b-7fca2fa7ad38
# ╠═5b9b0a72-6f22-4d5f-bef8-472ac7f021b3
# ╟─f420ea7e-469c-4ef0-a914-4635da9fd0d0
# ╠═1729df66-ee97-44ef-a871-7c8b20e68534
# ╟─f7c8fe21-4d23-4304-9496-a616d0d80768
# ╠═75c9658b-b730-4e0f-a3b3-98ea643074da
# ╟─7a0b9bd7-96b0-4f3d-ae5a-55483d4d994a
# ╠═0a2c368d-d7ea-4f04-b25c-e45a0809741f
# ╟─5cae5e83-9248-4dc2-8e1d-99caf59abf82
# ╠═5b5ee6c2-4761-440d-8f0f-003bc5c874d8
# ╟─9979cc23-21d3-4434-a0ef-d0d87de02e69
# ╠═707f015a-98bb-4a07-bc9a-83a5c0a3632a
