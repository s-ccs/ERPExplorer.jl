struct SelectSet
    items::Observable{Vector{Any}}
    value::Observable{Vector{Any}}
end

function SelectSet(items)
    return SelectSet(Base.convert(Observable{Vector{Any}}, items), Base.convert(Observable{Vector{Any}}, items))
end

function JSServe.jsrender(s::Session, selector::SelectSet)
    rows = map(selector.items[]) do value
        c = JSServe.Checkbox(true; class="p-1 m-1")
        on(s, c.value) do x
            values = selector.value[]
            has_item = (value in values)
            if x
                !has_item && push!(values, value)
            else
                has_item && filter!(x -> x != value, values)
            end
            notify(selector.value)
        end
        return D.FlexRow(value, c)
    end
    return JSServe.jsrender(s, D.Card(D.FlexCol(rows...)))
end

function value_range(args)
    type = args[end-1]
    default_values = args[end]
    if (type == :ContinuousTerm) || (type == :BSplineTerm)
        mini = round(Int, default_values.min)
        maxi = round(Int, default_values.max)
        if (maxi - mini) < 2
            return mini:0.1:maxi
        else
            return mini:maxi
        end
    elseif type == :CategoricalTerm
        return Set(default_values)
    else
        error("No widget for $(args)")
    end
end

function widget(range::AbstractRange{<:Number})
    @show range
    range_slider = RangeSlider(range; value=Any[minimum(range), maximum(range)])
    @show range_slider
    range_slider.ticks[] = Dict(
        "mode" => "range",
        "density" => 10
    )
    range_slider.orientation[] = JSServe.WidgetsBase.vertical
    return range_slider
end

function widget(values::Set)
    return SelectSet(collect(values))
end

function formular_text(content; class="")
    return DOM.div(content; class="px-1 text-lg m-1 font-semibold $(class)")
end

function dropdown(name, content)
    return DOM.div(formular_text(name), DOM.div(content; class="dropdown-content"); class=" bg-slate-100 hover:bg-lime-100 dropdown")
end

function style_map(::AbstractRange{<:Number})
    return Dict(
        :color => identity,
        :colormap => RGBAf.(Colors.color.(to_colormap(:lighttest)), 0.5)
    )
end

function style_map(values::Set)
    mpalette = [:circle, :star4, :xcross, :diamond]
    dict = Dict(v => mpalette[i] for (i, v) in enumerate(values))
    mcmap = Makie.wong_colors(0.5)
    mcolor_lookup = Dict(v => mcmap[i] for (i, v) in enumerate(values))
    return Dict(
        :marker => v -> dict[v],
        :marker_color => mcolor_lookup
    )
end

function select_vspan(scene; blocking=false, priority=2, kwargs...)
    key = Mouse.left
    waspressed = Observable(false)
    rect = Observable(Rectf(0, 0, 1, 1)) # plotted rectangle
    rect_ret = Observable(Rectf(0, 0, 1, 1)) # returned rectangle

    # Create an initially hidden rectangle
    low = Observable(0.0f0)
    high = Observable(0.0f0)

    on(rect) do r
        low.val = r.origin[1]
        high[] = r.origin[1] + r.widths[1]
    end
    plotted_span = vspan!(
        scene, low, high, visible=false, kwargs..., transparency=true, color=(:black, 0.1)
    )

    on(events(scene).mousebutton, priority=priority) do event
        if event.button == key
            if event.action == Mouse.press && is_mouseinside(scene)
                mp = mouseposition(scene)
                waspressed[] = true
                plotted_span[:visible] = true # start displaying
                rect[] = Rectf(mp, 0.0, 0.0)
                return Consume(blocking)
            end
        end
        if !(event.button == key && event.action == Mouse.press)
            if waspressed[] # User has selected the rectangle
                waspressed[] = false
                r = Makie.absrect(rect[])
                w, h = widths(r)
                #if w > 0.0# && h > 0.0 # Ensure that the rectangle has non0 size.
                rect_ret[] = r
                #end
            end
            # always hide if not the right key is pressed
            #plotted_span[:visible] = false # make the plotted rectangle invisible
            return Consume(blocking)
        end

        return Consume(false)
    end
    on(events(scene).mouseposition, priority=priority) do event
        if waspressed[]
            mp = mouseposition(scene)
            mini = minimum(rect[])
            rect[] = Rectf(mini, mp - mini)
            return Consume(blocking)
        end
        return Consume(false)
    end

    return rect_ret, plotted_span
end

function rectselect(ax)
    selrect, h = select_vspan(ax.scene; color=(0.9))
    translate!(h, 0, 0, -1) # move to background
    return selrect
end
