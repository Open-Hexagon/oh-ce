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
local settings = require("config").settings
local categories = settings.categories
local area_element = ui.area_element
local scroll = area_element.scroll
local blank_background = area_element.blank_background
local id = ui.new_id_table()
local toggle = ui.element.toggle
local slider = ui.element.slider
local switch = ui.element.switch
local typing = ui.control.typing
local profile_registry_list = settings.profile_registry_list
local suppress = ui.suppress

local menu_width = 800
local category_bar_width = 75
local category_icon_size = 54

local slide_in_out = signal.new_queue(-menu_width)

local menu = {}

local function close()
    ui.layer.retire()
end

function menu.on_push()
    slide_in_out:keyframe(0.1, 0, ease.out_sine)
end

function menu.on_pop(release)
    slide_in_out:keyframe(0.1, -menu_width, ease.out_sine)
    slide_in_out:call(release)
end

local rename_state = {}
local currently_renaming
local function draw_setting_profile_entry(name)
    local is_current_profile = name == settings.get_current_profile()
    cursor.push()
    cursor.auto_reshape = "no"
    local sid = mnav.declare_sensor_id()
    local delete_sid = mnav.declare_sensor_id()
    local reset_sid = mnav.declare_sensor_id()
    local rename_sid = mnav.declare_sensor_id()

    -- currently_renaming has to be set before running make_text_entry
    -- This is so make_text_entry sees this same frame as it being clicked on.
    if mnav.get_clicked(rename_sid) then
        currently_renaming = name
    end

    if currently_renaming == name then
        typing.make_text_entry(rename_state, rename_sid)
        typing.draw_text_entry(24, "Rename")
        if typing.stopped_editing(rename_state) then
            if #rename_state.text > 0 then
                pcall(settings.rename_profile, name, rename_state.text)
            end
            typing.truncate(rename_state)
            currently_renaming = nil
        end
    else
        draw_by_cursor.label(name, 24, "left", false, is_current_profile and theme.accent_color or theme.white)
    end

    if mnav.is_hovering(sid) then
        cursor.change_anchor(1, 0.5)
        cursor.width = 32
        cursor.change_anchor(0.5)

        if is_current_profile then
            suppress.push_disable()
        end
        mnav.make_sensor(delete_sid)
        icon_button(24, "x-square", delete_sid)
        tooltip("bottom", "Delete", 16, "center")
        if mnav.get_clicked(delete_sid) then
            settings.delete_profile(name)
        end
        if is_current_profile then
            suppress.pop_disable()
        end
        cursor.shift_left()

        mnav.make_sensor(reset_sid)
        icon_button(24, "arrow-clockwise", reset_sid)
        tooltip("bottom", "Reset to defaults", 16, "center")
        if mnav.get_clicked(reset_sid) then
            settings.reset_profile(name)
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
        and not mnav.is_hovering(rename_sid)
        and mnav.get_clicked(sid)
    then
        settings.open_profile(name)
    end
    cursor.pop()
    cursor.shift_down()
end

local create_state = {}
function menu.main()
    local screen_width = cursor.width

    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.v_split(math.min(menu_width, screen_width)) -- (2)
    cursor.pop() -- (2.1)

    draw_by_cursor.rectangle(theme.settings_menu_bg_color)

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

    scroll.finish(8, 12, 8, 28, 100)

    ui.draw.set_shader(theme.settings_menu_fade_down_shader)
    cursor.change_anchor(0)
    cursor.height = 8
    draw_by_cursor.rectangle(theme.settings_menu_right_shadow_color)
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
    cursor.auto_reshape = "width"
    icon_button(24, "plus-square")
    tooltip("bottom", "New settings profile", 16, "center")
    local create_profile_sid = mnav.get_current_sensor_id()

    -- content
    cursor.pop() -- (5.2)

    scroll.start(id.scroll)
    cursor.clip(12, 4, 24, 0)
    cursor.height = 32
    cursor.change_anchor(0, 0.5)

    -- use a while loop since the profile registry list might change length while iterating
    local i = 1
    while i <= #profile_registry_list do
        draw_setting_profile_entry(profile_registry_list[i])
        i = i + 1
    end

    typing.make_text_entry(create_state, create_profile_sid)
    if typing.is_editing(create_state) then
        typing.draw_text_entry(24, "new profile")
    end
    if typing.stopped_editing(create_state) then
        if #create_state.text > 0 then
            pcall(settings.create_profile, create_state.text)
        end
        typing.truncate(create_state)
    end

    cursor.change_anchor(0)

    scroll.finish(8, 12, 4, 24, 100)

    ui.draw.set_shader(theme.settings_menu_fade_down_shader)
    cursor.height = 8
    draw_by_cursor.rectangle(theme.settings_menu_right_shadow_color)
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
