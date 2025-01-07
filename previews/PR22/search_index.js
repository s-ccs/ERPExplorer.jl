var documenterSearchIndex = {"docs":
[{"location":"api/","page":"API / DocStrings","title":"API / DocStrings","text":"Modules = [ERPExplorer]\nOrder   = [:function]","category":"page"},{"location":"api/#ERPExplorer.create_plot!-NTuple{6, Any}","page":"API / DocStrings","title":"ERPExplorer.create_plot!","text":"create_plot!(plots, data, vars, scatter_styles, line_styles, continuous_vars)\n\nArguments:\n- plots - a SpecApi list to push into.\n- data - a DataFrame to be subsetted.\n- vars contains the levels to be plotted.\n Return Value: .\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.formular_widgets-Tuple{Any}","page":"API / DocStrings","title":"ERPExplorer.formular_widgets","text":"formular_widgets(variables)\n\nCreates widgets to control each variable of a model.\nArguments:\n- variables\n\nReturn Values:\n\nwidget_signal: a signal that emits a dictionary with the current values of the widgets.\nformular_widget: The HTML element that can be displayed to interact with the the widgets\nvalue_ranges: A dictionary with the value ranges of each variable.\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.plot_data-NTuple{5, Any}","page":"API / DocStrings","title":"ERPExplorer.plot_data","text":"plot_data(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)\n\ndata: effects(Dict(...), m) \nvalue_ranges:\ncategorical_vars:\ncontinuous_vars:\nmapping: Dict name=>property.\n\nReturn Value: DataFrames.\n\n\n\n\n\n","category":"method"},{"location":"api/","page":"API / DocStrings","title":"API / DocStrings","text":"Internally, we use a PlotConfig struct to keep track of common plotting options, so that all functions have a similar API.","category":"page"},{"location":"#ERPExplorer-Highlights","page":"ERPExplorer highlights","title":"ERPExplorer Highlights","text":"","category":"section"},{"location":"","page":"ERPExplorer highlights","title":"ERPExplorer highlights","text":"ERPExplorer.jl allows interactive exploration of regression-ERPs. You can switch on and off formula terms, term values, row and column faceting, line colours and style, marker style.","category":"page"}]
}
