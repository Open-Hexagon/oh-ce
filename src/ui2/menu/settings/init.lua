local ui = require("ohui")
local theme = ui.theme
local cursor = ui.cursor
local layer = ui.layer
local draw = ui.draw
local text = ui.text
local draw_by_cursor = draw.by_cursor
local draw_by_id = draw.by_id
local mnav = ui.control.mouse_navigation
local smode = mnav.sensor_mode
local area_element = ui.area_element
local scroll = area_element.scroll
local blank_background = area_element.blank_background
local icon_button = ui.element.icon_button
local tooltip = ui.decorator.tooltip
local search = text.search
local typing = ui.control.typing

local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local set_error_message = require("ui2.menu.debug").set_error_message
local settings = require("config").settings
local profile_display_list = settings.profile_display_list
local categories = settings.categories
local properties = settings.properties

local id = ui.new_id_table()

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
    menu_width,
    category_bar_width,
    category_icon_size,
    fade_down_shader
)

local search_bar_height = 64

--#region profile dropdown

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
        layer.pop()
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
            layer.pop()
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
    draw.set_shader(fade_down_shader)
    draw_by_cursor.rectangle(shadow40_color)
    draw.set_shader()
    scroll.finish(8, 0, 0, 0, 0)
    cursor.v_fit_screen()
    draw_by_cursor.left_line(theme.white, 2, "inside")
    draw_by_cursor.right_line(theme.white, 2, "inside")
end

--#endregion

local settings_table = settings.get_all()

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

local function refresh_visuals(name)
    local state = id[name]
    local property = properties[name]
    state.initialized = nil
    if type(property.default) == "boolean" then
        state.on = settings.get(name)
    elseif property.options then
        state.position = settings_table[name]
    elseif type(property.default) == "number" then
        state.value = settings_table[name]
    end
end

local function refresh_all_visuals()
    for name, _ in pairs(properties) do
        refresh_visuals(name)
    end
end

local search_state = {}

local function is_searching()
    return typing.has_text(search_state)
end

local search_results = {}
local search_results_index = 0

local function run_search()
    if not is_searching() then
        return
    end

    local matches, score, marked_text, t
    local old_index = search_results_index
    search_results_index = 0

    local category, property
    for i = 1, #categories do
        category = categories[i]
        if category.name == "hidden" then
            goto continue
        end
        for j = 1, #category do
            property = category[j]
            if not are_dependencies_satisfied(property) then
                goto continue
            end
            matches, score, marked_text = search(search_state.text, property.display_name, "%tc%", "%hc%")
            if not matches then
                goto continue
            end
            search_results_index = search_results_index + 1
            search_results[search_results_index] = search_results[search_results_index] or { true, true, true, true }
            t = search_results[search_results_index]
            t[1] = i
            t[2] = score
            t[3] = property
            t[4] = marked_text
            ::continue::
        end
        ::continue::
    end

    -- clear old entries
    for i = search_results_index + 1, old_index do
        search_results[i] = nil
    end

    table.sort(search_results, function(a, b)
        if a[1] == b[1] then
            if a[2] == b[2] then
                return a[3].display_name < b[3].display_name -- alphabetical
            end
            return a[2] > b[2] -- highest score
        end
        return a[1] < b[1] -- category order
    end)
end

---@type function, function
local draw_setting, intercept_inputs = loadfile("src/ui2/menu/settings/draw_setting.lua")(
    refresh_visuals,
    refresh_all_visuals,
    id,
    are_dependencies_satisfied,
    run_search
)

local menu = {}
menu.intercept_inputs = intercept_inputs

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
    layer.retire()
end

function menu.on_push()
    slide_in_out:keyframe(0.1, 0, ease.out_sine)
    refresh_all_visuals()
end

function menu.on_reveal()
    run_search()
    refresh_all_visuals()
end

function menu.on_pop(release)
    slide_in_out:keyframe(0.1, -menu_width, ease.out_sine)
    slide_in_out:call(release)
end

local last_viewed_category
local category_bar_scroll = {}
local main_scroll = {}
local no_search_results_text = text.get_icon_string("question-circle-fill") .. " No search results"
function menu.main()
    local screen_width = cursor.width
    local jump_to_category = nil
    local sp_seletor_sid
    local search_sid

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

    cursor.change_anchor(0.5, 0)
    cursor.auto_reshape = "height"

    icon_button(category_icon_size, "arrow-left-circle-fill")
    tooltip("right", "Back", 24, "left")
    cursor.shift_down()
    if mnav.get_clicked() then
        close()
    end

    icon_button(category_icon_size, "person-circle")
    tooltip("right", "Profiles", 24, "left")
    if mnav.get_clicked() then
        layer.push(profile_switcher_menu)
    end

    cursor.shift_down()
    cursor.height = 10
    draw_by_cursor.h_center_line(theme.white, 2, 8)
    cursor.shift_down()
    cursor.bottom_to_screen()
    scroll.start(category_bar_scroll)
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
    scroll.finish(3, 0, 0, 0, 0)

    --#endregion

    cursor.peek() -- (3.2)

    cursor.h_split(search_bar_height + profile_dropdown_height, true) -- (4)
    cursor.pop() -- (4.1)

    if dropdown_menu_is_open then
        cursor.export(profile_dropdown)
    end

    --#region settings list

    scroll.start(main_scroll)
    -- forces the scroll content to be a constant width, even if the scroll region needs to be shrunk by the window being too small.
    cursor.width = menu_width - category_bar_width
    cursor.clip(12, 8, 28, 0)

    cursor.auto_reshape = "height"

    if is_searching() then
        if typing.just_modified(search_state) then
            run_search()
        end

        if search_results_index == 0 then
            cursor.auto_area_expansion = "cursor"
            cursor.height = 32
            cursor.y = cursor.y + 30
            draw_by_cursor.label(no_search_results_text, 24, "left", false, theme.yellow)
            cursor.shift_down(10)
        end

        -- use while loops since search results might change
        local j = 1
        local current_category_index
        while j <= search_results_index do
            current_category_index = search_results[j][1]

            blank_background.start(1)

            draw_by_cursor.label(categories[current_category_index].name, 32, "left", false)
            cursor.shift_down(10)

            cursor.auto_area_expansion = "cursor"
            while j <= search_results_index and search_results[j][1] == current_category_index do
                draw_setting(search_results[j][3], search_results[j][4])
                j = j + 1
            end

            cursor.auto_area_expansion = "no" -- don't let blank background interfere with scroll content area
            local res_id, pid = blank_background.finish(6, 0, 8, 8)
            cursor.auto_area_expansion = "placement"

            if area_element.is_auto_scroll_active() and current_category_index == last_viewed_category then
                draw.next_takes_reservation(res_id)
                draw_by_id.rectangle(pid, "line", 0, 0, 2, unpack(theme.accent_color))
            else
                draw.close_reservation(res_id)
            end

            local h = cursor.height
            cursor.height = 10000
            scroll.auto_scroll_region(jump_to_category == current_category_index)
            cursor.height = h

            cursor.shift_down(10)
        end
    else
        for i = 1, #categories do
            local category = categories[i]

            blank_background.start(1)

            draw_by_cursor.label(category.name, 32, "left", false)
            cursor.shift_down(10)

            cursor.auto_area_expansion = "cursor"
            for j = 1, #category do
                draw_setting(category[j])
            end

            cursor.auto_area_expansion = "no" -- don't let blank background interfere with scroll content area
            local res_id, pid = blank_background.finish(6, 0, 8, 8)
            cursor.auto_area_expansion = "placement"

            if area_element.is_auto_scroll_active() and i == last_viewed_category then
                draw.next_takes_reservation(res_id)
                draw_by_id.rectangle(pid, "line", 0, 0, 2, unpack(theme.accent_color))
            else
                draw.close_reservation(res_id)
            end

            local h = cursor.height
            cursor.height = 10000
            scroll.auto_scroll_region(jump_to_category == i)
            cursor.height = h

            cursor.shift_down(10)
        end
    end

    scroll.finish(8, 12, 8, 28, 200)

    -- draw the shadow at the top of the scroll that separates it from the profile dropdown
    cursor.height = 8
    draw.set_shader(fade_down_shader)
    draw_by_cursor.rectangle(shadow40_color)
    draw.set_shader()

    --#endregion

    cursor.pop() -- (4.2)

    --#region profile dropdown menu

    cursor.h_split(search_bar_height, true) -- (5)
    cursor.pop() -- (5.1)
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
        layer.push(profile_dropdown)
    end
    tooltip("bottom", "Switch settings profile", 16, "left")

    cursor.width = 28
    cursor.change_anchor(0.5, 0.5)
    draw_by_cursor.icon(dropdown_menu_is_open and "caret-down-fill" or "caret-right-fill", 20)
    cursor.shift_right()
    cursor.change_anchor(0, 0.5)
    draw_by_cursor.label(settings.get_current_profile(), 20, "left", false)

    --#endregion

    cursor.pop() -- (5.2)

    --#region search bar

    cursor.auto_reshape = "no"

    search_sid = mnav.make_sensor()
    if mnav.is_hovering(search_sid) and not typing.is_editing(search_state) then
        -- use scrollbar colors since they work well
        if mnav.get_holding(search_sid) then
            draw_by_cursor.rectangle(theme.grabbed_scrollbar)
        else
            draw_by_cursor.rectangle(theme.scrollbar)
        end
    end
    typing.make_text_entry(search_state, search_sid)

    cursor.clip(12, 0, 4, 0)
    if is_searching() then
        cursor.push()
        cursor.change_anchor(1, 0.5)
        cursor.width = 48
        cursor.change_anchor(0.5)
        cursor.auto_reshape = "both"
        icon_button(32, "x-square")
        tooltip("bottom", "Clear search", 16, "left")
        if mnav.get_clicked() then
            typing.truncate(search_state)
        end
        cursor.pop()
    end

    cursor.clip_right(48)
    typing.draw_text_entry(search_state, 32, "Search settings")

    --#endregion

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
