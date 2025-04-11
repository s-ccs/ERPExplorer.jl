using PyMNE
using CSV

# read the events tsv file and save it in a DataFrame
evts_init = CSV.read("scripts/raw_gert/sub-09_task-WLFO_events.tsv", DataFrame, delim="\t") #5898×20
ix = evts_init.type .== "fixation"
events = evts_init[ix, 2:end] #128×2067879
#rename!(events, names(events)[1] => "latency")

 # read the raw eeg data set
raw = PyMNE.io.read_raw_eeglab("scripts/raw_gert/sub-09_task-WLFO_eeg.set", preload = true)

eeg_data_1 = raw.get_data(units="uV")
eeg_data_2 = pyconvert(Array{Float64}, eeg_data_1) #128×2067879

srate = pyconvert(Float64, raw.info["sfreq"])
events.latency .= events.onset .* srate
eeg_data, times = Unfold.epoch(eeg_data_2, events, (-0.5, 1), srate)

formulaS = @formula(0 ~ 1 + duration + fix_avgpupilsize)
model = Unfold.fit(UnfoldModel, formulaS, events, eeg_data, times)

_, positions = TopoPlots.example_data()

ERPExplorer.explore(model; positions = positions)