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

-- scratch variables
local A

function settings.main()
    cursor.push_translation(slide_in_out(), 0) -- (1)

    cursor.push()

    cursor.width = menu_width
    draw_by_cursor.rectangle(bg_color)
    draw_by_cursor.right_line(theme.white, 2, "inside")

    cursor.push()

    --#region category bar

    cursor.width = category_bar_width
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

    cursor.pop()

    --#region settings list

    cursor.clip_left(category_bar_width)
    cursor.clip_top(75)
    draw_by_cursor.top_line(theme.white, 2, "inside", 0.5)

    scroll.start(id.scroll)

    cursor.x = cursor.x + 12
    cursor.y = cursor.y + 8

    for i = 1, #categories do
        local category = categories[i]

        cursor.start_area()
        draw_by_cursor.label(category.name, 32, "left", false)
        cursor.shift_down(10)
        A = cursor.x
        cursor.x = cursor.x + 16
        for j = 1, #category do
            draw_by_cursor.label(category[j].display_name, 24, "left", false)
            mnav.make_sensor()
            tooltip("right", ".............................................................", 24, "left")
            cursor.shift_down(10)
        end
        cursor.x = A

        cursor.finish_area()
        A = cursor.height
        cursor.height = 10000
        scroll.auto_scroll_region(jump_to_category == i)
        cursor.height = A
        cursor.shift_down(10)
    end

    scroll.finish(8, 0)

    --#endregion

    cursor.pop()

    cursor.clip_left(menu_width)
    draw_by_cursor.vline({ 0, 0, 0, 0.2 }, 5, 0)
    mnav.make_sensor()
    if mnav.get_clicked() then
        close()
    end

    cursor.pop_translation() -- (1)
end

return settings
