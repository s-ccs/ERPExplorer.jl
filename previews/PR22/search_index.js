var documenterSearchIndex = {"docs":
[{"location":"api/","page":"API / DocStrings","title":"API / DocStrings","text":"Modules = [ERPExplorer]\nOrder   = [:function]","category":"page"},{"location":"api/#ERPExplorer.create_plot!-NTuple{6, Any}","page":"API / DocStrings","title":"ERPExplorer.create_plot!","text":"create_plot!(plots, data, vars, scatter_styles, line_styles, continuous_vars)\n\nArguments:\n- plots - a SpecApi list to push into.\n- data - a DataFrame to be subsetted.\n- vars contains the levels to be plotted.\n Return Value: .\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.extract_variables-Tuple{Any}","page":"API / DocStrings","title":"ERPExplorer.extract_variables","text":"extract_variables(model)\n\nTakes the Unfold model and extract variables from it for future functions. \n\nArguments:\n- model::UnfoldLinearModel{Float64} - Unfold linear model with categorical and continuous terms.\n\nThese variables are:\n\nnames - all terms of the model. \nsymbols- non-numeric terms of the model.\ntypes - types of terms.\n\nvals - min, max, variance, mean for continuous terms, levels for categorical terms. \n\nReturn Values: Vector{Pair{Symbol}}.\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.formular_widgets-Tuple{Any}","page":"API / DocStrings","title":"ERPExplorer.formular_widgets","text":"formular_widgets(variables)\n\nCreates widgets to control each variable of a model.\nArguments:\n- variables::Vector{Pair{Symbol}} - vector of key-value pairs with information about the model formula terms.\n\nActions:\n\nExtract ranges of term values.\nCreate widgets for each term (Slider for continuous, SelectSet for categorical).\nCreating the formula with checkboxes and translating to HTML code. \nConvert checkboxes to Observables. \n\nReturn Values:\n\nwidget_checkbox: Dictionary with the current values of the widgets (term => values).\nwidget_signal: widget_checkbox but as Observable, a signal that emits a dictionary with the current values of the widgets.\nformular_widget: The HTML element that can be displayed to interact with the the widgets.\nvalue_ranges: A dictionaryy containing the value ranges of each formula term.\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.mapping_dropdowns-Tuple{Any, Any}","page":"API / DocStrings","title":"ERPExplorer.mapping_dropdowns","text":"mapping_dropdowns(varnames, var_types)\n\nMaps dropdown menus on the left panel of the Figure.\n Arguments:\n- varnames::Vector{Symbol} - vector of the model formula terms.\n\nvar_types::Vector{Symbol} - vector of types of the model formula terms.\n\nActions:\n\nTake categorical variables and put their values into dropdown menus.\nThere will be 5 menus for: color, markers, line styles, column and row facets.\nMap each menu object with its name on the Figure.\nCreate HTML containers using Document Object Model (DOM) from Bonito. \nArrange containers on the panel using Col() and Row(). Specify their styling.\n\nReturn Values:\n\nmapping::Observable{Dict{Symbol, Symbol}} - interactive dictionary with menus and their default value.\nmapping_dom::Hyperscript.Node{Hyperscript.HTMLSVG} - dropdown menus in HTML code with styling and layout.\n\n\n\n\n\n","category":"method"},{"location":"api/#ERPExplorer.plot_data-NTuple{5, Any}","page":"API / DocStrings","title":"ERPExplorer.plot_data","text":"plot_data(data, value_ranges, categorical_vars, continuous_vars, mapping_obs)\n\ndata: effects(Dict(...), m) \nvalue_ranges:\ncategorical_vars:\ncontinuous_vars:\nmapping: Dict name=>property.\n\nReturn Value: DataFrames.\n\n\n\n\n\n","category":"method"},{"location":"api/","page":"API / DocStrings","title":"API / DocStrings","text":"Internally, we use a PlotConfig struct to keep track of common plotting options, so that all functions have a similar API.","category":"page"},{"location":"#ERPExplorer-Highlights","page":"ERPExplorer highlights","title":"ERPExplorer Highlights","text":"","category":"section"},{"location":"","page":"ERPExplorer highlights","title":"ERPExplorer highlights","text":"ERPExplorer.jl allows interactive exploration of regression-ERPs. You can switch on and off formula terms, term values, row and column faceting, line colours and style, marker style.","category":"page"}]
}
