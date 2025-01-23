function rectselect(ax)
    selrect, h = select_vspan(ax.scene; color = (0.9))
    translate!(h, 0, 0, -1) # move to background
    return selrect
end

function Bonito.jsrender(s::Session, selector::SelectSet)
    rows = map(selector.items[]) do value
        c = Bonito.Checkbox(true; class = "p-1 m-1")
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
        return Row(value, c)
    end
    return Bonito.jsrender(s, Card(Col(rows...)))
end

function style_map(::AbstractRange{<:Number})
    return Dict(
        :color => identity,
        :colormap => RGBAf.(Colors.color.(to_colormap(:lighttest)), 0.5),
    )
end

function style_map(values::Set)
    mpalette = [:circle, :star4, :xcross, :diamond]
    dict = Dict(v => mpalette[i] for (i, v) in enumerate(values))
    mcmap = Makie.wong_colors(0.5)
    mcolor_lookup = Dict(v => mcmap[i] for (i, v) in enumerate(values))
    return Dict(:marker => v -> dict[v], :marker_color => mcolor_lookup)
end

function select_vspan(scene; blocking = false, priority = 2, kwargs...)
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
        scene,
        low,
        high,
        visible = false,
        kwargs...,
        transparency = true,
        color = (:black, 0.1),
    )

    on(events(scene).mousebutton, priority = priority) do event
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
                rect_ret[] = r
            end
            # always hide if not the right key is pressed
            #plotted_span[:visible] = false # make the plotted rectangle invisible
            return Consume(blocking)
        end

        return Consume(false)
    end
    on(events(scene).mouseposition, priority = priority) do event
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

function Bonito.jsrender(s::Session, selector::SelectSet)
    rows = map(selector.items[]) do value
        c = Bonito.Checkbox(true; class = "p-1 m-1")
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
        return Row(value, c)
    end
    return Bonito.jsrender(s, Card(Col(rows...)))
end
