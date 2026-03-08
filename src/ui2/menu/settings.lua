local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local draw_by_cursor = ui.draw.by_cursor
local icon_button = ui.element.icon_button
local mnav = ui.control.mouse_navigation
local smode = mnav.sensor_mode
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local tooltip = ui.decorator.tooltip
local config = require("config")
local categories = config.categories
local scroll = ui.area_element.scroll
local id = ui.new_id_table()
local toggle = ui.element.toggle
local slider = ui.element.slider

local settings = {}

local bg_color = { 0, 0, 0, 0.8 }

local category_icons = {
    Gameplay = "hexagon",
    UI = "stack",
    Audio = "volume-up",
    General = "gear",
    Display = "display",
    Input = "controller",
}
local category_tooltip_text = {
    Gameplay = "Gameplay settings",
    UI = "User interface settings",
    Audio = "Sound settings",
    General = "General settings",
    Display = "Display settings",
    Input = "Input configuration",
}

local menu_width = 800
local category_bar_width = 75
local category_icon_size = 54

local slide_in_out = signal.new_queue(-menu_width)

local function close()
    ui.layer.retire()
end

function settings.on_push()
    slide_in_out:keyframe(0.1, 0, ease.out_sine)
end

function settings.on_pop(release)
    slide_in_out:keyframe(0.1, -menu_width, ease.out_sine)
    slide_in_out:call(release)
end

local function draw_setting(property)
    local sid, state
    state = id[property.name]
    if type(property.default) == "boolean" then
        sid = mnav.declare_sensor_id()
        cursor.height = 32
        cursor.push()
        do
            cursor.auto_reshape = "no"
            cursor.auto_area_expansion = "cursor"
            cursor.change_anchor(0, 0.5)
            cursor.clip_left(16)

            draw_by_cursor.label(
                property.display_name,
                24,
                "left",
                false,
                state.on and theme.accent_color or theme.text_color
            )

            cursor.change_anchor(1, 0.5)
            toggle(state, sid)

            if mnav.is_hovering(sid) then
                draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
                draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
            end
            if property.tooltip then
                tooltip("right", property.tooltip, 20, "left", nil, sid)
            end
        end
        cursor.peek()
        cursor.h_stretch(100)
        mnav.make_sensor(sid)
        cursor.pop()
        cursor.shift_down()
    elseif type(property.default) == "number" then
        if not (property.min and property.max) then
            return
        end
        if property.positions then
            sid = mnav.declare_sensor_id()
            local slider_sid = mnav.declare_sensor_id()
            local actual_value
            cursor.height = 32
            cursor.push()
            do
                cursor.auto_reshape = "no"
                cursor.auto_area_expansion = "cursor"
                cursor.change_anchor(0, 0.5)
                cursor.clip_left(16)
                draw_by_cursor.label(property.display_name, 24, "left", false)

                if mnav.is_hovering(sid) or mnav.get_dragging(slider_sid) then
                    draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
                    draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
                end
                if property.tooltip then
                    tooltip("right", property.tooltip, 20, "left", nil, sid)
                end

                cursor.change_anchor(1, 0.5)
                cursor.width = 150
                mnav.make_sensor(slider_sid, smode.draggable)
                slider(state, property.min, property.max, property.positions, property.show_positions, slider_sid)
                cursor.shift_left(10)

                if property.special_min_value and state.value == property.min then
                    actual_value = property.special_min_value
                elseif property.special_max_value and state.value == property.max then
                    actual_value = property.special_max_value
                else
                    actual_value = state.value
                end

                if type(property.format) == "string" and type(actual_value) == "number" then
                    draw_by_cursor.label(string.format(property.format, actual_value), 20, "right", false)
                elseif type(property.format) == "function" then
                    draw_by_cursor.label(property.format(actual_value), 20, "right", false)
                else
                    draw_by_cursor.label(tostring(actual_value), 20, "right", false)
                end
            end
            cursor.peek()
            cursor.h_stretch(100)
            mnav.make_sensor(sid)
            cursor.pop()
            cursor.shift_down()
        elseif property.step then
            cursor.shift_down()
        else
            return
        end
    else
        draw_by_cursor.label(property.display_name, 24, "left", false)
        mnav.make_sensor()
        tooltip("right", "<placeholder>", 20, "left")
        cursor.shift_down()
    end
end

-- scratch variables
local A

function settings.main()
    local screen_width = cursor.width

    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.v_split(math.min(menu_width, screen_width)) -- (2)
    cursor.pop() -- (2.1)

    draw_by_cursor.rectangle(bg_color)
    draw_by_cursor.right_line(theme.white, 2, "inside")

    cursor.v_split(category_bar_width) --(3)
    cursor.pop() -- (3.1)

    --#region category bar

    draw_by_cursor.right_line(theme.white, 2, "outside")
    cursor.change_anchor(0.5, 0)

    icon_button(category_icon_size, "arrow-left-circle-fill")
    tooltip("right", "Back", 24, "left")
    cursor.shift_down()
    if mnav.get_clicked() then
        close()
    end

    local jump_to_category = nil

    for i = 1, #categories do
        local category = categories[i]
        icon_button(category_icon_size, category_icons[category.name])
        if mnav.get_clicked() then
            jump_to_category = i
        end
        tooltip("right", category_tooltip_text[category.name], 24, "left")
        cursor.shift_down()
    end

    --#endregion

    cursor.pop() -- (3.2)

    cursor.h_split(75, true) -- (4)
    cursor.pop() -- (4.1)

    --#region settings list

    scroll.start(id.scroll)

    cursor.clip(12, 8, 28, 0)

    cursor.auto_reshape = "height"

    for i = 1, #categories do
        local category = categories[i]

        cursor.start_area()

        draw_by_cursor.label(category.name, 32, "left", false)
        cursor.shift_down(10)

        for j = 1, #category do
            draw_setting(category[j])
        end

        cursor.finish_area()

        A = cursor.height
        cursor.height = 10000
        scroll.auto_scroll_region(jump_to_category == i)
        cursor.height = A

        cursor.shift_down(10)
    end

    scroll.finish(8, 0)

    draw_by_cursor.top_line(theme.white, 2, "inside", 0.5)

    --#endregion

    cursor.pop() -- (4.2)

    cursor.change_anchor(0.5)
    draw_by_cursor.label("Search", 24, "left", false)

    cursor.pop() -- (2.2)

    draw_by_cursor.vline({ 0, 0, 0, 0.2 }, 5, 0)
    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation() -- (1)
end

return settings
