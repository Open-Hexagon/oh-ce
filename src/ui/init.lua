local signal = require("ui.anim.signal")
local overlay = require("ui.overlay")
local overlays = overlay.overlays
local game_handler = require("game_handler")
local scroll = require("ui.layout.scroll")
local config = require("config")
local key_repeat = require("ui.key_repeat")
local flex = require("ui.layout.flex")
local ui = {}
local keyboard_navigation = require("ui.keyboard_navigation")
local current_screen
local grabbed_element
local transform = love.math.newTransform()

---set an element to be the only one to receive the next mousereleased event
---@param elem any
function ui.set_grabbed(elem)
    grabbed_element = elem
end

---get the currently grabbed element
---@return unknown
function ui.get_grabbed()
    return grabbed_element
end

---set gui scale
---@param scale number
function ui.set_scale(scale)
    if current_screen then
        current_screen:set_scale(scale)
        current_screen._transform:reset()
        current_screen._transform:apply(transform)
    end
end

function ui.get_dimensions()
    local game_width, game_height
    if game_handler.is_running() then
        game_width, game_height = game_handler.get_game_dimensions()
    end
    local width = game_width or love.graphics.getWidth()
    local height = game_height or love.graphics.getHeight()
    return width, height
end

function ui.calculate_full_layout(layout_transform, layout)
    layout_transform:reset()
    if game_handler.is_running() then
        layout_transform:translate(game_handler.get_game_position())
    end
    local width, height = ui.get_dimensions()
    local scale = config.get("gui_scale")
    if config.get("area_based_gui_scale") then
        -- 1080p as reference for user setting in this scale mode
        scale = scale / math.max(1920 / width, 1080 / height)
    end
    if layout == current_screen then
        ui.set_scale(scale)
    else
        layout:set_scale(scale)
    end
    local res_width, res_height = layout:calculate_layout(width, height)
    -- as long as the resulting layout is smaller than the window, up gui scale (until user setting is reached)
    while res_width < width and res_height < height do
        local new_scale = layout.scale + 0.1
        if new_scale > scale then
            break
        end
        layout:set_scale(new_scale)
        res_width, res_height = layout:calculate_layout(width, height)
    end
    -- as long as the resulting layout is too big for the window, lower gui scale
    while res_width > width or res_height > height do
        local new_scale = layout.scale - 0.1
        if new_scale <= 0.1 then
            return
        end
        layout:set_scale(new_scale)
        res_width, res_height = layout:calculate_layout(width, height)
    end
end

local function calculate_layout()
    ui.calculate_full_layout(transform, current_screen)
    overlays.update_layout()
end

---open a menu screen
---@param name string
function ui.open_screen(name)
    current_screen = require("ui.screens." .. name)
    if current_screen then
        calculate_layout()
        keyboard_navigation.set_screen(current_screen)
    end
end

---get currently open screen
---@return table
function ui.get_screen()
    return current_screen
end

---process a window event
---@param name string
---@param ... unknown
function ui.process_event(name, ...)
    -- reset scrolled_already value (determines if a container can still scroll, ensures child priority over parent with scrolling (children are processed before parents))
    scroll.scrolled_already = false
    love.graphics.origin()
    if current_screen then
        if name == "resize" then
            calculate_layout()
        end
    end
    if ui.extra_element then
        if ui.extra_element:process_event(name, ...) then
            return
        end
    end
    if name == "mousereleased" and grabbed_element then
        love.graphics.translate(grabbed_element.x, grabbed_element.y)
        grabbed_element:process_event(name, ...)
        grabbed_element = nil
        return
    end
    local stop_propagation = overlays.process_event(name, ...)
    if current_screen then
        if not stop_propagation then
            stop_propagation = current_screen:process_event(name, ...)
        end
        if not stop_propagation and keyboard_navigation.get_screen() == current_screen then
            keyboard_navigation.process_event(name, ...)
        end
    end
end

---update animations
---@param dt number
function ui.update(dt)
    if flex.must_calculate_alignement then
        flex.must_calculate_alignement = false
        flex.process_alignement()
    end
    key_repeat.update(dt)
    signal.update(dt)
end

---draw the ui
function ui.draw()
    if current_screen then
        current_screen:draw()
    end
    overlays.draw()
end

return ui
