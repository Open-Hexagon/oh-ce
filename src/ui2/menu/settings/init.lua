local ui = require("ohui")
local theme = ui.theme
local cursor = ui.cursor
local draw = ui.draw
local draw_by_cursor = draw.by_cursor
local draw_by_id = draw.by_id
local icon_button = ui.element.icon_button
local mnav = ui.control.mouse_navigation
local smode = mnav.sensor_mode
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local tooltip = ui.decorator.tooltip
local settings = require("config").settings
local categories = settings.categories
local area_element = ui.area_element
local scroll = area_element.scroll
local blank_background = area_element.blank_background
local id = ui.new_id_table()
local toggle = ui.element.toggle
local slider = ui.element.slider
local switch = ui.element.switch
local profile_display_list = settings.profile_display_list
local suppress = ui.suppress
local set_error_message = require("ui2.menu.debug").set_error_message

local bg_color = { 0.13, 0.15, 0.19, 1 }
local shadow40_color = { 0, 0, 0, 0.4 }
local shadow20_color = { 0, 0, 0, 0.2 }
local menu_width = 800
local category_bar_width = 75
local category_icon_size = 54
local fade_down_shader = love.graphics.newShader([[
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    color.a *= 1 - texture_coords.y;
    return color;
}
]])

local profile_switcher_menu = loadfile("src/ui2/menu/settings/profile_switcher.lua")(
    bg_color,
    shadow40_color,
    shadow20_color,
    menu_width,
    category_bar_width,
    category_icon_size,
    fade_down_shader
)

local search_bar_height = 74
local profile_dropdown_height = 26

local profile_dropdown = {}
local dropdown_scroll = {}
local dropdown_menu_is_open = false

function profile_dropdown.on_push()
    dropdown_menu_is_open = true
    settings.sort_profile_display_list()
end

function profile_dropdown.on_pop()
    dropdown_menu_is_open = false
end

function profile_dropdown.main()
    mnav.make_sensor()
    if mnav.get_clicked() then
        ui.layer.pop()
    end
    cursor.import(profile_dropdown)
    cursor.auto_reshape = "no"
    scroll.start(dropdown_scroll)
    cursor.height = profile_dropdown_height
    for i = 1, #settings.profile_display_list do
        local name = profile_display_list[i]
        local is_current_profile = name == settings.get_current_profile()
        draw_by_cursor.rectangle(bg_color)
        draw_by_cursor.top_line(shadow20_color, 1, "inside", 1)
        mnav.make_sensor(nil, smode.block)
        if mnav.is_hovering() then
            -- use scrollbar colors since they work well
            if mnav.get_holding() then
                draw_by_cursor.rectangle(theme.grabbed_scrollbar)
            else
                draw_by_cursor.rectangle(theme.scrollbar)
            end
        end
        if mnav.get_clicked() then
            if not is_current_profile then
                local success, msg = settings.open_profile(name)
                if not success then
                    set_error_message(msg)
                end
            end
            ui.layer.pop()
        end
        cursor.push()
        cursor.width = 28
        if is_current_profile then
            cursor.change_anchor(0.5, 0.5)
            draw_by_cursor.icon("asterisk", 20)
        end
        cursor.shift_right()
        cursor.change_anchor(0, 0.5)
        draw_by_cursor.label(name, 20, "left", false, is_current_profile and theme.accent_color or theme.text_color)
        cursor.pop()
        cursor.shift_down()
    end
    cursor.height = 8
    ui.draw.set_shader(fade_down_shader)
    draw_by_cursor.rectangle(shadow40_color)
    ui.draw.set_shader()
    scroll.finish(8, 0)
    cursor.v_fit_screen()
    draw_by_cursor.left_line(theme.white, 2, "inside")
    draw_by_cursor.right_line(theme.white, 2, "inside")
end

local menu = {}

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

local slide_in_out = signal.new_queue(-menu_width)

local function close()
    ui.layer.retire()
end

local settings_table = settings.get_all()
local function refresh_visuals()
    for name, property in pairs(settings.properties) do
        local state = id[name]
        state.initialized = nil
        if type(property.default) == "boolean" then
            state.on = settings.get(name)
        elseif property.options then
            state.position = settings_table[name]
        elseif type(property.default) == "number" then
            state.value = settings_table[name]
        end
    end
end

function menu.on_push()
    slide_in_out:keyframe(0.1, 0, ease.out_sine)
    refresh_visuals()
end

function menu.on_reveal()
    refresh_visuals()
end

function menu.on_pop(release)
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
        if mnav.get_clicked(sid) then
            settings.set(property.name, state.on)
            if property.onchange then
                property.onchange(state.value)
            end
            -- ! dumb hack to make the toggle switches show default values when official mode is on
            -- ! only the toggle settings have this feature for now
            if property.name == "official_mode" then
                refresh_visuals()
            end
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
    local display_value
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

        local has_incremented = false
        if property.inc_dec_buttons then
            sid_plus = mnav.declare_sensor_id()
            sid_minus = mnav.declare_sensor_id()

            cursor.width = 20
            cursor.change_anchor(0.5, 0.5)
            mnav.make_sensor(sid_plus)
            icon_button(32, "plus", sid_plus)
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
                    has_incremented = true
                elseif mnav.get_clicked(sid_minus) then
                    state.position = state.position - 1
                    has_incremented = true
                end
                property.inc_dec_buttons = 0
            end
        end

        cursor.width = 150
        mnav.make_sensor(slider_sid, smode.draggable)
        slider(state, property.min, property.max, property.positions, property.show_positions, slider_sid)
        cursor.shift_left(10)

        if property.inc_dec_buttons then
            cursor.width = 20
            cursor.change_anchor(0.5, 0.5)
            mnav.make_sensor(sid_minus)
            icon_button(32, "hyphen", sid_minus)
            cursor.change_anchor(1, 0.5)
            cursor.shift_left(10)
        end

        if property.min_display_text and state.value == property.min then
            display_value = property.min_display_text
        elseif property.max_display_text and state.value == property.max then
            display_value = property.max_display_text
        else
            display_value = state.value
        end

        if has_incremented or mnav.get_stopped_dragging(slider_sid) or mnav.get_clicked(slider_sid) then
            settings.set(property.name, state.value)
            if property.onchange then
                property.onchange(state.value)
            end
        end

        if type(property.format) == "string" and type(display_value) == "number" then
            draw_by_cursor.label(string.format(property.format, display_value), 20, "right", false)
        elseif type(property.format) == "function" then
            draw_by_cursor.label(property.format(display_value), 20, "right", false)
        else
            draw_by_cursor.label(tostring(display_value), 20, "right", false)
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
        local old_position = state.position
        switch(state, sid, unpack(property.options))

        if mnav.get_clicked(sid) and old_position ~= state.position then
            settings.set(property.name, state.position)
            if property.onchange then
                property.onchange(state.position)
            end
        end
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()
end

local function are_dependencies_satisfied(property)
    if not property.dependencies then
        return true
    end
    for name, required_value in pairs(property.dependencies) do
        if settings_table[name] ~= required_value then
            return false
        end
    end
    return true
end

local function draw_setting(property)
    local disable = not are_dependencies_satisfied(property)
    if disable then
        suppress.push_disable()
    end

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

    if disable then
        suppress.pop_disable()
    end
end

-- scratch variables
local A
local last_viewed_category
local main_scroll = {}
function menu.main()
    local screen_width = cursor.width
    local jump_to_category = nil
    local sp_seletor_sid

    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.v_split(math.min(menu_width, screen_width)) -- (2)
    cursor.pop() -- (2.1)

    if profile_switcher_menu.fully_extended then
        goto skip_menu_contents
    end

    draw_by_cursor.rectangle(bg_color)

    cursor.v_split(category_bar_width) --(3)
    cursor.pop() -- (3.1)

    --#region category bar

    -- TODO category bar should get a scroll
    cursor.change_anchor(0.5, 0)

    icon_button(category_icon_size, "arrow-left-circle-fill")
    tooltip("right", "Back", 24, "left")
    cursor.shift_down()
    if mnav.get_clicked() then
        close()
    end

    icon_button(category_icon_size, "person-circle")
    tooltip("right", "Profiles", 24, "left")
    if mnav.get_clicked() then
        ui.layer.push(profile_switcher_menu)
    end

    cursor.shift_down()
    cursor.height = 10
    draw_by_cursor.h_center_line(theme.white, 2)
    cursor.shift_down()

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

    cursor.h_split(search_bar_height + profile_dropdown_height, true) -- (4)
    cursor.pop() -- (4.1)

    if dropdown_menu_is_open then
        cursor.export(profile_dropdown)
    end

    --#region settings list

    scroll.start(main_scroll)
    cursor.width = menu_width - category_bar_width

    cursor.clip(12, 8, 28, 0)

    cursor.auto_reshape = "height"

    for i = 1, #categories do
        local category = categories[i]

        blank_background.start(1)

        draw_by_cursor.label(category.name, 32, "left", false)
        cursor.shift_down(10)

        for j = 1, #category do
            draw_setting(category[j])
        end

        cursor.auto_area_expansion = "no" -- don't interfere with scroll content area
        local res_id, pid = blank_background.finish(6, 0, 8, 8)
        cursor.auto_area_expansion = "placement"

        if ui.area_element.is_auto_scroll_active() and i == last_viewed_category then
            draw.next_takes_reservation(res_id)
            draw_by_id.rectangle(pid, "line", 0, 0, 2, unpack(theme.accent_color))
        else
            draw.close_reservation(res_id)
        end

        A = cursor.height
        cursor.height = 10000
        scroll.auto_scroll_region(jump_to_category == i)
        cursor.height = A

        cursor.shift_down(10)
    end

    scroll.finish(8, 12, 8, 28, 200)

    cursor.height = 8
    ui.draw.set_shader(fade_down_shader)
    draw_by_cursor.rectangle(shadow40_color)
    ui.draw.set_shader()

    --#endregion

    cursor.pop() -- (4.2)

    cursor.h_split(search_bar_height, true)
    cursor.pop()
    cursor.auto_reshape = "no"
    draw_by_cursor.top_line(shadow20_color, 1, "inside", 1)
    sp_seletor_sid = mnav.make_sensor()
    if mnav.is_hovering(sp_seletor_sid) or dropdown_menu_is_open then
        -- use scrollbar colors since they work well
        if mnav.get_holding(sp_seletor_sid) then
            draw_by_cursor.rectangle(theme.grabbed_scrollbar)
        else
            draw_by_cursor.rectangle(theme.scrollbar)
        end
    end
    if mnav.get_clicked(sp_seletor_sid) then
        ui.layer.push(profile_dropdown)
    end

    cursor.width = 28
    cursor.change_anchor(0.5, 0.5)
    draw_by_cursor.icon(dropdown_menu_is_open and "caret-down-fill" or "caret-right-fill", 20)
    cursor.shift_right()
    cursor.change_anchor(0, 0.5)
    draw_by_cursor.label(settings.get_current_profile(), 20, "left", false)

    cursor.pop()
    cursor.auto_reshape = "no"
    cursor.change_anchor(0.5)
    draw_by_cursor.label("Search", 24, "left", false)

    cursor.pop() -- (3.2)

    draw_by_cursor.left_line(theme.white, 2, "inside")
    draw_by_cursor.right_line(theme.white, 2, "inside")

    ::skip_menu_contents::
    cursor.pop() -- (2.2)

    draw_by_cursor.left_line(shadow20_color, 5, "inside")
    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation() -- (1)
end

return menu
