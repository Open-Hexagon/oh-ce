local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local draw_by_cursor = ui.draw.by_cursor
local icon_button = ui.element.icon_button
local mnav = ui.control.mouse_navigation
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local tooltip = ui.decorator.tooltip
local settings = require("config").settings
local area_element = ui.area_element
local scroll = area_element.scroll
local id = ui.new_id_table()
local checkbox = ui.element.checkbox
local typing = ui.control.typing
local profile_display_list = settings.profile_display_list
local set_error_message = require("ui2.menu.debug").set_error_message

local bg_color, shadow40_color, menu_width, category_bar_width, category_icon_size, fade_down_shader =
    ...

local slide_in_out = signal.new_queue(-menu_width)

local menu = {
    -- used to tell the settings menu that it's okay to stop rendering the menu
    fully_extended = false,
}

local function close()
    ui.layer.retire()
end

function menu.on_push()
    slide_in_out:keyframe(0.1, 0, ease.out_sine)
    slide_in_out:call(function()
        menu.fully_extended = true
    end)
end

function menu.on_pop(release)
    slide_in_out:keyframe(0.1, -menu_width, ease.out_sine)
    slide_in_out:call(release)
    menu.fully_extended = false
end

local rename_state = {}
local currently_renaming
local success, msg
local function draw_setting_profile_entry(name)
    local is_current_profile = name == settings.get_current_profile()
    local sid = mnav.declare_sensor_id()
    local delete_sid = mnav.declare_sensor_id()
    local reset_sid = mnav.declare_sensor_id()
    local copy_sid = mnav.declare_sensor_id()
    local rename_sid = mnav.declare_sensor_id()

    cursor.push()
    cursor.auto_reshape = "no"

    cursor.v_split(40)
    cursor.pop()
    -- position isn't used by text entry so we can be sneaky and use it here
    rename_state.position = is_current_profile and 2 or 0
    checkbox(rename_state, 24, 0) -- use 0 as custom sensor to disable mouse interaction entirely

    cursor.pop()
    -- currently_renaming has to be set before running make_text_entry
    -- This is so make_text_entry sees this same frame as it being clicked on.
    if mnav.get_clicked(rename_sid) then
        currently_renaming = name
        rename_state.text = name
    end
    if currently_renaming == name then
        typing.make_text_entry(rename_state, rename_sid)
        typing.draw_text_entry(rename_state, 24, "Rename profile", theme.get_xterm_color(87))
        local stop_method = typing.stopped_editing(rename_state)
        if stop_method then
            if stop_method ~= "escape" then
                local new_text = rename_state.text --[[@as string]]
                -- trim leading and trailing whitespace
                new_text = new_text:gsub("^%s*(.*)%s*$", "%1")
                if #new_text > 0 and new_text ~= currently_renaming then
                    success, msg = settings.rename_profile(name, new_text)
                    if not success then
                        set_error_message(msg)
                    end
                end
            end
            typing.truncate(rename_state)
            currently_renaming = nil
        end
    else
        if mnav.is_hovering(sid) then
            cursor.width = cursor.width - 128
        end
        draw_by_cursor.push_mask()
        draw_by_cursor.label(name, 24, "left", false, is_current_profile and theme.accent_color or theme.white)
        ui.draw.pop_mask()
    end

    cursor.peek()
    cursor.auto_reshape = "no"

    if mnav.is_hovering(sid) then
        -- selection lines
        draw_by_cursor.top_line(theme.accent_color, 2, "center", -2)
        draw_by_cursor.bottom_line(theme.accent_color, 2, "center", -2)

        cursor.change_anchor(1, 0.5)
        cursor.width = 32
        cursor.change_anchor(0.5)

        mnav.make_sensor(delete_sid)
        icon_button(24, "x-square", delete_sid)
        tooltip("bottom", "Delete", 16, "center")
        if mnav.get_clicked(delete_sid) then
            success, msg = settings.delete_profile(name)
            if not success then
                set_error_message(msg)
            end
        end
        cursor.shift_left()

        mnav.make_sensor(reset_sid)
        icon_button(24, "arrow-clockwise", reset_sid)
        tooltip("bottom", "Reset to defaults", 16, "center")
        if mnav.get_clicked(reset_sid) then
            success, msg = settings.reset_profile(name)
            if not success then
                set_error_message(msg)
            end
        end
        cursor.shift_left()

        mnav.make_sensor(copy_sid)
        icon_button(24, "copy", copy_sid)
        tooltip("bottom", "Duplicate", 16, "center")
        if mnav.get_clicked(copy_sid) then
            local n = 2
            local disambiguator = " copy"
            success = false
            while not success do
                success, msg = settings.copy_profile(name, name .. disambiguator)
                disambiguator = " copy" .. n
                n = n + 1
            end
        end
        cursor.shift_left()

        mnav.make_sensor(rename_sid)
        icon_button(24, "pencil", rename_sid)
        tooltip("bottom", "Rename", 16, "center")
    end
    cursor.peek()
    cursor.h_stretch(100)
    mnav.make_sensor(sid)
    if
        not mnav.is_hovering(delete_sid)
        and not mnav.is_hovering(reset_sid)
        and not mnav.is_hovering(copy_sid)
        and not mnav.is_hovering(rename_sid)
        and mnav.get_clicked(sid)
        and not is_current_profile
    then
        success, msg = settings.open_profile(name)
        if not success then
            set_error_message(msg)
        end
    end
    cursor.pop()
    cursor.shift_down()
end

local create_state = {}
local sort_direction = false
function menu.main()
    local screen_width = cursor.width

    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.v_split(math.min(menu_width, screen_width)) -- (2)
    cursor.pop() -- (2.1)

    draw_by_cursor.rectangle(bg_color)

    -- split between categoy bar and profile selection
    cursor.v_split(category_bar_width) -- (3)
    cursor.pop() -- (3.1)

    --#region category bar

    cursor.change_anchor(0.5, 0)
    icon_button(category_icon_size, "arrow-left-circle-fill")
    tooltip("right", "Back", 24, "left")
    cursor.shift_down()
    if mnav.get_clicked() then
        close()
    end

    --#endregion

    cursor.peek() -- (3.2)

    -- split for profile lists
    cursor.auto_reshape = "height"
    cursor.h_split_norm(0.5) -- (4)
    cursor.pop() -- (4.1)

    --#region game profiles

    cursor.h_split(40) -- (5)
    cursor.pop() -- (5.1)
    cursor.clip(12, 0, 28, 0)
    cursor.change_anchor(0, 0.5)
    draw_by_cursor.label("Score profiles", 24, "left", false)

    cursor.pop() -- (5.2)
    scroll.start(id.scroll)
    cursor.width = menu_width - category_bar_width
    cursor.clip(12, 8, 28, 0)

    -- TODO nothing to display for now

    scroll.finish(8, 12, 8, 28, 100)

    ui.draw.set_shader(fade_down_shader)
    cursor.change_anchor(0)
    cursor.height = 8
    draw_by_cursor.rectangle(shadow40_color)
    ui.draw.set_shader()

    --#endregion

    cursor.peek() -- (4.2)

    --#region setting profiles

    -- header
    cursor.h_split(40) -- (5)
    cursor.pop() -- (5.1)
    cursor.auto_reshape = "no"
    cursor.clip(12, 0, 8, 0)
    cursor.change_anchor(0, 0.5)
    draw_by_cursor.label("Settings profiles", 24, "left", false)

    cursor.change_anchor(1, 0.5)
    cursor.width = 32
    cursor.height = 32
    cursor.change_anchor(0.5)
    local create_profile_sid = mnav.make_sensor()
    icon_button(24, "plus-square", create_profile_sid)
    tooltip("bottom", "New settings profile", 16, "center")
    cursor.shift_left()
    local sort_sid = mnav.make_sensor()
    icon_button(24, sort_direction and "caret-up-fill" or "caret-down-fill", sort_sid)
    tooltip("bottom", "Sort", 16, "center")
    if mnav.get_clicked(sort_sid) then
        sort_direction = not sort_direction
        settings.sort_profile_display_list(sort_direction)
    end

    -- content
    cursor.pop() -- (5.2)

    scroll.start(id.scroll)
    cursor.clip(12, 4, 24, 0)
    cursor.height = 32
    cursor.change_anchor(0, 0.5)

    -- use a while loop since the profile registry list might change length while iterating
    local i = 1
    while i <= #profile_display_list do
        draw_setting_profile_entry(profile_display_list[i])
        i = i + 1
    end

    -- the create new profile text entry doesn't affect the scroll region
    -- it's already padded at the bottom so this is okay
    cursor.auto_area_expansion = "no"

    scroll.auto_scroll_region(not not mnav.get_clicked(create_profile_sid))
    typing.make_text_entry(create_state, create_profile_sid)
    if typing.is_editing(create_state) then
        typing.draw_text_entry(create_state, 24, "New profile name", theme.get_xterm_color(87))
    end
    local stop_method = typing.stopped_editing(create_state)
    if stop_method then
        if stop_method ~= "escape" then
            local new_text = create_state.text --[[@as string]]
            -- trim leading and trailing whitespace
            new_text = new_text:gsub("^%s*(.-)%s*$", "%1")
            if #new_text > 0 then
                success, msg = settings.create_profile(new_text)
                if not success then
                    set_error_message(msg)
                end
            end
        end
        typing.truncate(create_state)
    end

    scroll.finish(8, 12, 4, 24, 100)

    ui.draw.set_shader(fade_down_shader)
    cursor.height = 8
    draw_by_cursor.rectangle(shadow40_color)
    ui.draw.set_shader()

    --#endregion

    cursor.pop() -- (4.2)
    draw_by_cursor.top_line(theme.white, 2, "center", 1)
    cursor.pop() -- (3.2)
    draw_by_cursor.left_line(theme.white, 2, "inside")
    draw_by_cursor.right_line(theme.white, 2, "inside")

    cursor.pop() -- (2.2)

    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation() -- (1)
end

return menu
