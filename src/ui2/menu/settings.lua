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

local menu_width = 600
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

function settings.main()
    cursor.push_translation(slide_in_out(), 0)

    cursor.push()
    cursor.width = menu_width
    mnav.make_sensor(nil, smode.block, smode.disable)

    draw_by_cursor.rectangle(bg_color)
    draw_by_cursor.right_line(theme.white, 2, "inside")

    cursor.width = category_bar_width
    draw_by_cursor.right_line(theme.white, 2, "outside")

    cursor.change_anchor(0.5, 0)
    icon_button(category_icon_size, "arrow-left-circle-fill")
    tooltip("right", "Back", 24, "left")
    cursor.shift_down()
    if mnav.get_clicked() then
        close()
    end
    icon_button(category_icon_size, "hexagon")
    tooltip("right", "Gameplay settings", 24, "left")
    cursor.shift_down()
    icon_button(category_icon_size, "stack")
    tooltip("right", "User interface settings", 24, "left")
    cursor.shift_down()
    icon_button(category_icon_size, "volume-up")
    tooltip("right", "Sound settings", 24, "left")
    cursor.shift_down()
    icon_button(category_icon_size, "gear")
    tooltip("right", "General settings", 24, "left")
    cursor.shift_down()
    icon_button(category_icon_size, "display")
    tooltip("right", "Display settings", 24, "left")
    cursor.shift_down()
    icon_button(category_icon_size, "controller")
    tooltip("right", "Input configuration", 24, "left")

    cursor.pop()
    cursor.width = 9999
    cursor.clip_left(menu_width)
    draw_by_cursor.vline({ 0, 0, 0, 0.2 }, 5, 0)
    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation()
end

return settings
