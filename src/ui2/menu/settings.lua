local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local draw_by_cursor = ui.draw.by_cursor
local draw_by_id = ui.draw.by_id
local icon_button = ui.element.icon_button
local mnav = ui.control.mouse_navigation
local smode = mnav.sensor_mode
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local tooltip = ui.decorator.tooltip
local config = require("config")
local categories = config.categories
local area_element = ui.area_element
local scroll = area_element.scroll
local blank_background = area_element.blank_background
local id = ui.new_id_table()
local toggle = ui.element.toggle
local slider = ui.element.slider
local switch = ui.element.switch

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

local function draw_toggle(state, property)
    local sid = mnav.declare_sensor_id()
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
            tooltip("right", property.tooltip, 20, "left", nil, nil, sid)
        end
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()
end

local HOLD_ACTIVATE_TIME = 0.2
local HOLD_REPEAT_PERIOD = 0.008
local function draw_slider(state, property)
    local sid = mnav.declare_sensor_id()
    local sid_plus, sid_minus
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
            tooltip("right", property.tooltip, 20, "left", nil, mnav.get_dragging(slider_sid), sid)
        end

        cursor.change_anchor(1, 0.5)

        if property.inc_dec_buttons then
            cursor.width = 20
            cursor.change_anchor(0.5, 0.5)
            sid_plus = mnav.make_sensor()
            icon_button(32, "plus", sid_plus)
            cursor.change_anchor(1, 0.5)
            cursor.shift_left(10)
        end

        cursor.width = 150
        mnav.make_sensor(slider_sid, smode.draggable)
        slider(state, property.min, property.max, property.positions, property.show_positions, slider_sid)
        cursor.shift_left(10)

        if property.inc_dec_buttons then
            cursor.width = 20
            cursor.change_anchor(0.5, 0.5)
            sid_minus = mnav.make_sensor()
            icon_button(32, "hyphen", sid_minus)
            cursor.change_anchor(1, 0.5)
            cursor.shift_left(10)

            if mnav.get_holding(sid_plus) then
                property.inc_dec_buttons = property.inc_dec_buttons + love.timer.getDelta()
                while property.inc_dec_buttons > HOLD_ACTIVATE_TIME do
                    state.position = state.position + 1
                    property.inc_dec_buttons = property.inc_dec_buttons - HOLD_REPEAT_PERIOD
                end
            elseif mnav.get_holding(sid_minus) then
                property.inc_dec_buttons = property.inc_dec_buttons + love.timer.getDelta()
                while property.inc_dec_buttons > HOLD_ACTIVATE_TIME do
                    state.position = state.position - 1
                    property.inc_dec_buttons = property.inc_dec_buttons - HOLD_REPEAT_PERIOD
                end
            else
                if mnav.get_clicked(sid_plus) then
                    state.position = state.position + 1
                elseif mnav.get_clicked(sid_minus) then
                    state.position = state.position - 1
                end
                property.inc_dec_buttons = 0
            end
        end

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
end

local function draw_switch(state, property)
    local sid = mnav.declare_sensor_id()
    cursor.height = 32
    cursor.push()
    do
        cursor.auto_reshape = "no"
        cursor.auto_area_expansion = "cursor"
        cursor.change_anchor(0, 0.5)
        cursor.clip_left(16)
        draw_by_cursor.label(property.display_name, 24, "left", false)
        if mnav.is_hovering(sid) then
            draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
            draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
        end
        if property.tooltip then
            tooltip("right", property.tooltip, 20, "left", nil, nil, sid)
        end

        cursor.change_anchor(1, 0.5)
        cursor.width = 120 * #property.options
        switch(state, sid, unpack(property.options))
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()
end

local function draw_setting(property)
    local state = id[property.name]
    if type(property.default) == "boolean" then
        draw_toggle(state, property)
    elseif property.options then
        draw_switch(state, property)
    elseif type(property.default) == "number" then
        if not (property.min and property.max) then
            return
        elseif property.positions then
            draw_slider(state, property)
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
local last_viewed_category

function settings.main()
    local screen_width = cursor.width

    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.v_split(math.min(menu_width, screen_width)) -- (2)
    cursor.pop() -- (2.1)

    draw_by_cursor.rectangle(bg_color)

    cursor.v_split(category_bar_width) --(3)
    cursor.pop() -- (3.1)

    --#region category bar

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
            last_viewed_category = i
        end
        tooltip("right", category_tooltip_text[category.name], 24, "left")
        cursor.shift_down()
    end

    --#endregion

    cursor.peek() -- (3.2)

    cursor.h_split(75, true) -- (4)
    cursor.pop() -- (4.1)

    --#region settings list

    scroll.start(id.scroll)
    cursor.width = menu_width - category_bar_width

    cursor.clip(12, 8, 28, 0)

    cursor.auto_reshape = "height"

    for i = 1, #categories do
        local category = categories[i]

        blank_background.start()

        draw_by_cursor.label(category.name, 32, "left", false)
        cursor.shift_down(10)

        for j = 1, #category do
            draw_setting(category[j])
        end

        cursor.auto_area_expansion = "no" -- don't interfere with scroll content area
        local res_id, pid = blank_background.finish(6, 0, 8, 8)
        cursor.auto_area_expansion = "placement"

        if ui.area_element.is_auto_scroll_active() and i == last_viewed_category then
            ui.draw.next_takes_reservation(res_id)
            draw_by_id.rectangle(pid, "line", 0, 0, 2, unpack(theme.accent_color))
        else
            ui.draw.close_reservation(res_id)
        end

        A = cursor.height
        cursor.height = 10000
        scroll.auto_scroll_region(jump_to_category == i)
        cursor.height = A

        cursor.shift_down(10)
    end

    scroll.finish(8, 12, 8, 28, 200)

    draw_by_cursor.top_line(theme.white, 2, "inside", 0.5)

    --#endregion

    cursor.pop() -- (4.2)

    cursor.change_anchor(0.5)
    draw_by_cursor.label("Search", 24, "left", false)

    cursor.pop() -- (3.2)

    draw_by_cursor.left_line(theme.white, 2, "inside")
    draw_by_cursor.right_line(theme.white, 2, "inside")

    cursor.pop() -- (2.2)

    draw_by_cursor.vline({ 0, 0, 0, 0.2 }, 5, 0)
    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation() -- (1)
end

return settings
