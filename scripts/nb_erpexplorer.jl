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

# ╔═╡ 06575ce5-0ef4-4eb3-9e84-4b2e4c499ef6
using Makie

# ╔═╡ 73f3abf4-866f-4194-a0c2-8b00962b1292
W = ERPExplorer.WGLMakie

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

# ╔═╡ 31c93006-3860-4a8f-939a-a4d481d23429


# ╔═╡ 9a132228-97a7-4333-9b13-18266dc39ceb
b = Bonito.App() do
    #formular = Unfold.formula(model)
    variables = ERPExplorer.extract_variables(model)
    widget_signal, widget_dom, value_ranges = ERPExplorer.formular_widgets(variables)
    onany(widget_signal, value_ranges) do ws, vs
        @info ws, vs
    end
	#eff_signal = ERPExplorer.effects_signal(model, widget_signal)
        #varnames = first.(variables)
        #var_types = map(x -> x[2][3], variables)
        #obs = Observable(Makie.SpecApi.GridLayout())
        #l = Base.ReentrantLock()
        

	
    css = ERPExplorer.Asset(joinpath(@__DIR__, "..", "style.css"))
    return ERPExplorer.DOM.div(css, ERPExplorer.Bonito.TailwindCSS, widget_dom)
end



# ╔═╡ 0003f15f-fe81-4bde-825e-69420910888c
# ╠═╡ disabled = true
#=╠═╡
a = Bonito.App() do
    #formular = Unfold.formula(model)
    variables = ERPExplorer.extract_variables(model)
    widget_signal, widget_dom, value_ranges = ERPExplorer.formular_widgets(variables)
    onany(widget_signal, value_ranges) do ws, vs
        @info ws, vs
    end
    css = ERPExplorer.Asset(joinpath(@__DIR__, "..", "style.css"))
    return ERPExplorer.DOM.div(css, ERPExplorer.Bonito.TailwindCSS, widget_dom)
end


  ╠═╡ =#

# ╔═╡ 547506b2-9e26-4f3d-942b-d33ae2b275ed
# ╠═╡ disabled = true
#=╠═╡
begin
	function makie_plot(value)
    N = 10
    function xy_data(x, y)
        r = sqrt(x^2 + y^2)
        r == 0.0 ? 1.0f0 : (sin(r) / r)
    end
    l = range(-10, stop=10, length=N)
    z = Float32[xy_data(x, y) for x in l, y in l]
    W.surface(
		W.@lift(z.+$value),
        colormap=:Spectral,
        figure=(; size=(300, 300))
    )
end

App() do
	 s = Slider(1:3)
    value = map(s.value) do x
        return x ^ 2
    end
	    PCard(p) = Card(p, padding="0px", margin="0px")
    return Grid(
		DOM.div(s),
        PCard(makie_plot(value));
        columns="repeat(auto-fit, minmax(300px, 1fr))", justify_items="center")
end
end
  ╠═╡ =#

# ╔═╡ be44c547-0b9f-46ce-bd99-87b67eda3efb
Pkg.status()

# ╔═╡ Cell order:
# ╠═e0f77982-ccb6-11ee-29d7-153167e40b75
# ╠═6c02cf30-d3b7-4d9f-967e-a57010deea4e
# ╠═3349ebbc-198c-4fc1-b36e-7336e9d9868a
# ╠═23a7c086-9e37-4c8d-924d-e0cdfd3344a4
# ╠═73f3abf4-866f-4194-a0c2-8b00962b1292
# ╠═4ecdcafe-3e78-47c3-afb9-b97824a5d6ca
# ╠═1370e6d9-b231-4995-b9f5-e4582d3040e0
# ╠═6b675029-6d7b-40a2-811c-b72d394de884
# ╠═c643062c-e907-4c88-8cbe-86aba4012b3f
# ╠═31c93006-3860-4a8f-939a-a4d481d23429
# ╠═9a132228-97a7-4333-9b13-18266dc39ceb
# ╠═06575ce5-0ef4-4eb3-9e84-4b2e4c499ef6
# ╠═0003f15f-fe81-4bde-825e-69420910888c
# ╠═547506b2-9e26-4f3d-942b-d33ae2b275ed
# ╠═be44c547-0b9f-46ce-bd99-87b67eda3efb
