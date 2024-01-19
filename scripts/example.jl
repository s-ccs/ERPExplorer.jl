using Revise
using ERPExplorer

includet("gen_data.jl")
formulaS = @formula(0 ~ 1 + condition3 + condition2 + continuous + continuous3)
dataS, evts = gen_data()
times = range(0, length=size(dataS, 2), step=1 ./ 100)
model = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times)


app = explore(model)

port = 32415
url = "0.0.0.0"
server = Bonito.Server(app, url, port)




