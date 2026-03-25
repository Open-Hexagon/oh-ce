local ui = require("ohui")
local theme = ui.theme
local cursor = ui.cursor
local text = ui.text
local layer = ui.layer
local suppress = ui.suppress
local draw = ui.draw
local draw_by_cursor = draw.by_cursor
local mnav = ui.control.mouse_navigation
local mb = mnav.buttons
local smode = mnav.sensor_mode
local icon_button = ui.element.icon_button
local tooltip = ui.decorator.tooltip
local toggle = ui.element.toggle
local slider = ui.element.slider
local switch = ui.element.switch
local ansi = text.ansi

local set_error_message = require("ui2.menu.debug").set_error_message
local settings = require("config").settings

local settings_table = settings.get_all()

---@type function, function, table, function, function
local refresh_visuals, refresh_all_visuals, id, are_dependencies_satisfied, run_search = ...

local ansi_search_hl_color = ansi.to_sequence(theme.cyan)
local ansi_text_color = ansi.to_sequence(theme.text_color)
local ansi_accent_color = ansi.to_sequence(theme.accent_color)
local ansi_yellow = ansi.to_sequence(theme.yellow)
local icnstr_warning = text.get_icon_string("exclamation-triangle-fill")

local desc_tooltip_wrap_limit = 200

---@param mt string
---@param tc string
---@param hc string
---@return string, number
local function sub_marked_text(mt, tc, hc)
    return mt:gsub("%%tc%%", tc):gsub("%%hc%%", hc)
end

local function draw_toggle(state, property, marked_search_text, disable, desc_tooltip_space)
    local display_text
    if marked_search_text then
        display_text =
            sub_marked_text(marked_search_text, state.on and ansi_accent_color or ansi_text_color, ansi_search_hl_color)
    else
        display_text = (state.on and ansi_accent_color or ansi_text_color) .. property.display_name
    end

    local trigger_reset
    local sid = mnav.declare_sensor_id()
    cursor.height = 32
    cursor.push()
    do
        cursor.auto_reshape = "no"
        cursor.change_anchor(0, 0.5)

        if settings.is_default(property.name) then
            cursor.clip_left(32)
            mnav.declare_sensor_id()
        else
            cursor.v_split(32)
            cursor.pop()
            icon_button(24, "arrow-clockwise")
            trigger_reset = mnav.get_clicked()
            -- this tooltip doesn't conflict with the description tooltip because it comes first
            tooltip("bottom", "Reset", 16, "left")
            cursor.pop()
        end

        if disable then
            suppress.push_disable()
        end

        draw_by_cursor.label(display_text, 24, "left", false)

        cursor.change_anchor(1, 0.5)
        toggle(state, sid)
        cursor.change_anchor(0, 0.5)

        if mnav.is_hovering(sid) then
            draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
            draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
        end

        if property.tooltip then
            if desc_tooltip_space < desc_tooltip_wrap_limit then
                local x, _ = cursor.get_screen_dimensions()
                tooltip("bottom", property.tooltip, 16, "left", x, nil, sid)
            else
                tooltip("right", property.tooltip, 16, "left", desc_tooltip_space, nil, sid)
            end
        end

        if mnav.get_clicked(sid) == mb.left or trigger_reset then
            settings.set(property.name, state.on)
            if property.onchange then
                property.onchange(state.on)
            end
            -- ! dumb hack to make the toggle switches show default values when official mode is on
            -- ! only the toggle settings have this feature for now
            if property.name == "official_mode" then
                refresh_all_visuals()
            end
            run_search() -- rerun in case dependencies have changed
        end
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()

    if disable then
        suppress.pop_disable()
    end
end

local HOLD_ACTIVATE_TIME = 0.2
local HOLD_REPEAT_PERIOD = 0.008
local function draw_slider(state, property, marked_search_text, disable, desc_tooltip_space)
    local display_text
    if marked_search_text then
        display_text = sub_marked_text(marked_search_text, ansi_text_color, ansi_search_hl_color)
    else
        display_text = property.display_name
    end

    local sid = mnav.declare_sensor_id()
    local sid_plus, sid_minus
    local slider_sid = mnav.declare_sensor_id()
    local display_value
    cursor.height = 32
    cursor.push()
    do
        cursor.auto_reshape = "no"
        cursor.change_anchor(0, 0.5)

        if settings.is_default(property.name) then
            cursor.clip_left(32)
            mnav.declare_sensor_id()
        else
            cursor.v_split(32)
            cursor.pop()
            icon_button(24, "arrow-clockwise")
            tooltip("bottom", "Reset", 16, "left")
            if mnav.get_clicked() then
                settings.reset_setting(property.name)
                refresh_visuals(property.name)
                if property.onchange then
                    property.onchange(state.value)
                end
                run_search() -- rerun in case dependencies have changed
            end
            cursor.pop()
        end

        if disable then
            suppress.push_disable()
        end

        draw_by_cursor.label(display_text, 24, "left", false)

        if mnav.is_hovering(sid) or mnav.get_dragging(slider_sid) then
            draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
            draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
        end

        if property.tooltip then
            if desc_tooltip_space < desc_tooltip_wrap_limit then
                local x, _ = cursor.get_screen_dimensions()
                tooltip("bottom", property.tooltip, 16, "left", x, mnav.get_dragging(slider_sid), sid)
            else
                tooltip("right", property.tooltip, 16, "left", desc_tooltip_space, mnav.get_dragging(slider_sid), sid)
            end
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

            if mnav.get_holding(sid_plus) == mb.left then
                property.inc_dec_buttons = property.inc_dec_buttons + love.timer.getDelta()
                while property.inc_dec_buttons > HOLD_ACTIVATE_TIME do
                    state.position = state.position + 1
                    property.inc_dec_buttons = property.inc_dec_buttons - HOLD_REPEAT_PERIOD
                end
            elseif mnav.get_holding(sid_minus) == mb.left then
                property.inc_dec_buttons = property.inc_dec_buttons + love.timer.getDelta()
                while property.inc_dec_buttons > HOLD_ACTIVATE_TIME do
                    state.position = state.position - 1
                    property.inc_dec_buttons = property.inc_dec_buttons - HOLD_REPEAT_PERIOD
                end
            else
                if mnav.get_clicked(sid_plus) == mb.left then
                    state.position = state.position + 1
                    has_incremented = true
                elseif mnav.get_clicked(sid_minus) == mb.left then
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

        if has_incremented or mnav.get_stopped_dragging(slider_sid) or mnav.get_clicked(slider_sid) == mb.left then
            settings.set(property.name, state.value)
            if property.onchange then
                property.onchange(state.value)
            end
            run_search() -- rerun in case dependencies have changed
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

    if disable then
        suppress.pop_disable()
    end
end

local function draw_switch(state, property, marked_search_text, disable, desc_tooltip_space)
    local display_text
    if marked_search_text then
        display_text = sub_marked_text(marked_search_text, ansi_text_color, ansi_search_hl_color)
    else
        display_text = property.display_name
    end

    local sid = mnav.declare_sensor_id()
    cursor.height = 32
    cursor.push()
    do
        cursor.auto_reshape = "no"
        cursor.change_anchor(0, 0.5)

        if settings.is_default(property.name) then
            cursor.clip_left(32)
            mnav.declare_sensor_id()
        else
            cursor.v_split(32)
            cursor.pop()
            icon_button(24, "arrow-clockwise")
            tooltip("bottom", "Reset", 16, "left")
            if mnav.get_clicked() then
                settings.reset_setting(property.name)
                refresh_visuals(property.name)
                if property.onchange then
                    property.onchange(state.position)
                end
                run_search() -- rerun in case dependencies have changed
            end
            cursor.pop()
        end

        if disable then
            suppress.push_disable()
        end

        draw_by_cursor.label(display_text, 24, "left", false)

        if mnav.is_hovering(sid) then
            draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
            draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
        end

        if property.tooltip then
            if desc_tooltip_space < desc_tooltip_wrap_limit then
                local x, _ = cursor.get_screen_dimensions()
                tooltip("bottom", property.tooltip, 16, "left", x, nil, sid)
            else
                tooltip("right", property.tooltip, 16, "left", desc_tooltip_space, nil, sid)
            end
        end

        cursor.change_anchor(1, 0.5)
        cursor.width = (property.switch_unit_width or 120) * #property.options
        local old_position = state.position
        switch(state, sid, unpack(property.options))

        if mnav.get_clicked(sid) and old_position ~= state.position then
            settings.set(property.name, state.position)
            if property.onchange then
                property.onchange(state.position)
            end
            run_search() -- rerun in case dependencies have changed
        end
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()

    if disable then
        suppress.pop_disable()
    end
end

local input_intercepter = {}
local remapping

function input_intercepter.main()
    draw_by_cursor.rectangle({ 0, 0, 0, 0.8 })
    cursor.change_anchor(0.5)
    draw_by_cursor.label("Press any button", 32, "center", false)
end

local input_method_order = {
    "keyboard",
    "mouse",
    "touch",
}

local duplicate_bindings

local function get_input_key(method_name, binding)
    return method_name .. tostring(binding)
end

local function find_duplicate_bindings()
    duplicate_bindings = {}
    local input_settings = settings.categories["Input"]
    for i = 1, #input_settings do
        local methods = settings_table[input_settings[i].name]
        for method_name, bindings in pairs(methods) do
            for j = 1, #bindings do
                local key = get_input_key(method_name, bindings[j])
                if duplicate_bindings[key] == nil then
                    duplicate_bindings[key] = false
                elseif duplicate_bindings[key] == false then
                    duplicate_bindings[key] = true
                end
            end
        end
    end
end

-- initial setup
find_duplicate_bindings()

local function contains(t, v)
    for i = 1, #t do
        if t[i] == v then
            return true
        end
    end
    return false
end

local function intercept_inputs(name, a, b, c, d, e, f)
    if not remapping then
        return true
    end

    local methods = settings_table[remapping]
    if name == "keypressed" then
        methods.keyboard = methods.keyboard or {}
        if contains(methods.keyboard, a) then
            set_error_message(string.format("%s input already has keyboard key %s mapped", remapping, a:upper()))
        else
            table.insert(methods.keyboard, a)
            settings.set_dirty_flag()
            find_duplicate_bindings()
        end
        remapping = nil
        layer.pop()
    elseif name == "mousepressed" then
        methods.mouse = methods.mouse or {}
        if contains(methods.mouse, c) then
            set_error_message(string.format("%s input already has mouse button %d mapped", remapping, c))
        else
            table.insert(methods.mouse, c)
            settings.set_dirty_flag()
            find_duplicate_bindings()
        end
        remapping = nil
        layer.pop()
    end

    return false
end

local function translate_binding(method_name, binding)
    if method_name == "keyboard" then
        return "Keyboard " .. binding:upper()
    elseif method_name == "mouse" then
        if binding == 1 then
            return "Mouse LEFT"
        elseif binding == 2 then
            return "Mouse RIGHT"
        elseif binding == 3 then
            return "Mouse MIDDLE"
        else
            return string.format("Mouse BUTTON %d", binding)
        end
    elseif method_name == "touch" then
        -- TODO Touch bindings will probably be handled differently later
        return "Touch " .. tostring(binding)
    else
        return string.format("? %s %s", method_name, tostring(binding)):upper()
    end
end

-- cringe, but table serialization isn't reliable
local function are_inputs_equal(a, b)
    for method_name, bindings in pairs(a) do
        if not b[method_name] then
            return false
        end
        if #bindings ~= #b[method_name] then
            return false
        end
        for i = 1, #bindings do
            if not contains(b[method_name], bindings[i]) then
                return false
            end
        end
    end
    return true
end

local function draw_input_editor(state, property, marked_search_text)
    local sid, remove_input_sid, add_input_sid, display_text, methods
    sid = mnav.declare_sensor_id()
    cursor.y = cursor.y + 8
    cursor.height = 32
    cursor.start_area()
    do
        methods = settings.get(property.name)

        cursor.push()
        cursor.clip_left(32)
        cursor.auto_reshape = "both"
        cursor.change_anchor(1, 0.5)
        icon_button(24, "plus-square")
        tooltip("bottom", "Add input", 16, "left", nil, nil, add_input_sid)
        if mnav.get_clicked() then
            remapping = property.name
            layer.push(input_intercepter)
        end

        cursor.peek()
        cursor.auto_reshape = "width"
        cursor.auto_area_expansion = "placement"
        cursor.width = 140
        cursor.shift_right()

        local binding_count = 0
        for i = 1, #input_method_order do
            local method_name = input_method_order[i]
            local bindings = methods[method_name]
            if not bindings then
                goto continue
            end

            -- use while loop since length of bindings may change
            local j = 1
            while j <= #bindings do
                remove_input_sid = mnav.declare_sensor_id()
                cursor.push()
                cursor.start_area()
                icon_button(24, "x-square", remove_input_sid)
                cursor.shift_right(10)

                if duplicate_bindings[get_input_key(method_name, bindings[j])] then
                    draw_by_cursor.label(
                        string.format(
                            "%s %s",
                            translate_binding(method_name, bindings[j]),
                            text.get_icon_string("exclamation-triangle-fill")
                        ),
                        24,
                        "left",
                        false,
                        theme.red
                    )
                    tooltip(
                        "right",
                        "Duplicate input!\nWill likely cause unexpected behavior.",
                        16,
                        "left",
                        nil,
                        nil,
                        remove_input_sid
                    )
                else
                    draw_by_cursor.label(
                        translate_binding(method_name, bindings[j]),
                        24,
                        "left",
                        false,
                        mnav.is_hovering(remove_input_sid) and theme.accent_color or theme.text_color
                    )
                    tooltip("right", "Remove input", 16, "left", nil, nil, remove_input_sid)
                end

                cursor.finish_area()
                mnav.make_sensor(remove_input_sid)
                cursor.pop()
                cursor.shift_down()
                if mnav.get_clicked(remove_input_sid) == mb.left then
                    table.remove(bindings, j)
                    if #bindings == 0 then
                        methods[method_name] = nil
                    end
                    find_duplicate_bindings()
                    settings.set_dirty_flag()
                end
                binding_count = binding_count + 1
                j = j + 1
            end

            ::continue::
        end

        -- pad with 1 sensor id so a change in number of sensors caused by deleting inputs doesn't cause graphical errors (see above)
        -- this doesn't matter for resetting since that is always done at the end (see below)
        mnav.declare_sensor_id()

        cursor.pop()

        cursor.auto_reshape = "no"
        cursor.change_anchor(0, 0.5)

        if are_inputs_equal(property.default, methods) then
            cursor.place()
            cursor.clip_left(32)
            mnav.declare_sensor_id()
        else
            cursor.v_split(32)
            cursor.pop()
            icon_button(24, "arrow-clockwise")
            tooltip("bottom", "Reset", 16, "left")
            if mnav.get_clicked() then
                settings.reset_setting(property.name)
                find_duplicate_bindings()
                -- prevents the no mappings warning from showing up for 1 frame
                binding_count = 1
            end
            cursor.pop()
        end

        cursor.auto_reshape = "width"
        if binding_count == 0 then
            if marked_search_text then
                display_text = ansi_yellow
                    .. icnstr_warning
                    .. " "
                    .. sub_marked_text(marked_search_text, ansi_yellow, ansi_search_hl_color)
            else
                display_text = ansi_yellow .. icnstr_warning .. " " .. property.display_name
            end

            draw_by_cursor.label(display_text, 24, "left", false)
            mnav.make_sensor()
            tooltip("bottom", "No mappings!\nThis input is unable to be triggered.", 16, "center", 180)
        else
            if marked_search_text then
                display_text = sub_marked_text(marked_search_text, ansi_text_color, ansi_search_hl_color)
            else
                display_text = property.display_name
            end
            draw_by_cursor.label(display_text, 24, "left", false)
            mnav.declare_sensor_id()
        end
    end
    cursor.finish_area()
    cursor.v_stretch(8)
    cursor.push()

    cursor.place()
    cursor.clip_left(32)
    if mnav.is_hovering(sid) then
        draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
        draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)
    end

    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    cursor.pop()
    cursor.shift_down()
    cursor.change_anchor(0, 0) -- resets for next entry
end

---@param property table
---@param marked_search_text string?
local function draw_setting(property, desc_tooltip_space, marked_search_text)
    -- assert(cursor.auto_area_expansion == "cursor")
    -- assert(cursor.anchor_x == 0)
    -- assert(cursor.anchor_y == 0)

    local disable = false
    if not marked_search_text then
        -- search will already have omitted results without satisfied dependencies
        disable = not are_dependencies_satisfied(property)
    end

    local state = id[property.name]

    if type(property.default) == "boolean" then
        draw_toggle(state, property, marked_search_text, disable, desc_tooltip_space)
    elseif property.options then
        draw_switch(state, property, marked_search_text, disable, desc_tooltip_space)
    elseif type(property.default) == "number" then
        if not (property.min and property.max) then
            return
        elseif property.positions then
            draw_slider(state, property, marked_search_text, disable, desc_tooltip_space)
        else
            return
        end
    elseif property.category == "Input" then
        -- inputs will probably never have dependencies so they don't support disable
        draw_input_editor(state, property, marked_search_text)
    else
        local display_text
        if marked_search_text then
            display_text =
                sub_marked_text(marked_search_text, ansi.to_sequence(theme.text_color), ansi.to_sequence(theme.cyan))
        else
            display_text = property.display_name
        end
        draw_by_cursor.label(display_text, 24, "left", false)
        cursor.shift_down()
    end
end

return draw_setting, intercept_inputs
