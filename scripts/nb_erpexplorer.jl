### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# ╔═╡ e0f77982-ccb6-11ee-29d7-153167e40b75
begin
	using Pkg
	Pkg.activate(".")
end

# ╔═╡ 6c02cf30-d3b7-4d9f-967e-a57010deea4e
using PlutoLinks

# ╔═╡ 3349ebbc-198c-4fc1-b36e-7336e9d9868a
using ERPExplorer

# ╔═╡ 23a7c086-9e37-4c8d-924d-e0cdfd3344a4
using Bonito

# ╔═╡ 4ecdcafe-3e78-47c3-afb9-b97824a5d6ca
using Unfold,UnfoldSim,BSplineKit

# ╔═╡ 1370e6d9-b231-4995-b9f5-e4582d3040e0
simScript = @ingredients("gen_data.jl")

# ╔═╡ 6b675029-6d7b-40a2-811c-b72d394de884
begin
#formulaS = @formula(0 ~ 1 +luminance + contrast + saccade_amplitude + string + animal + fruit + color)
formulaS = @formula(0 ~ 1 + luminance + contrast + fruit + color)
formulaS = @formula(0 ~ 1 + color + fruit)
end

# ╔═╡ c643062c-e907-4c88-8cbe-86aba4012b3f
begin
dataS, evts = simScript.gen_data()

times = range(0, length=size(dataS, 2), step=1 ./ 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)
end

# ╔═╡ 02f98d4c-74df-4267-8a1d-7f9a52fc37a7
explore(model)

# ╔═╡ Cell order:
# ╠═e0f77982-ccb6-11ee-29d7-153167e40b75
# ╠═6c02cf30-d3b7-4d9f-967e-a57010deea4e
# ╠═3349ebbc-198c-4fc1-b36e-7336e9d9868a
# ╠═23a7c086-9e37-4c8d-924d-e0cdfd3344a4
# ╠═4ecdcafe-3e78-47c3-afb9-b97824a5d6ca
# ╠═1370e6d9-b231-4995-b9f5-e4582d3040e0
# ╠═6b675029-6d7b-40a2-811c-b72d394de884
# ╠═c643062c-e907-4c88-8cbe-86aba4012b3f
# ╠═02f98d4c-74df-4267-8a1d-7f9a52fc37a7
