local keyboard_navigation = require("ui.keyboard_navigation")
local game_handler = require("game_handler")
local signal = require("ui2.anim.signal")
local flex = require("ui.layout.flex")
local config = require("config")

local overlays = {}

---@class overlay
---@field is_open boolean
---@field layout table
---@field transition table
---@field backdrop boolean
---@field backdrop_alpha Queue
---@field closable_by_outside_click boolean
local overlay = {}
overlay.__index = overlay

---create a new overlay
---@return overlay
function overlay:new()
    local obj = setmetatable({
        is_open = false,
        layout = flex:new({}),
        transition = nil,
        has_opened_before = false,
        backdrop = true,
        backdrop_alpha = signal.new_queue(0),
        closable_by_outside_click = true,
    }, overlay)
    overlays[#overlays + 1] = obj
    return obj
end

---calculate layout (only used internally)
function overlay:update_layout()
    require("ui").calculate_full_layout(self.layout._transform, self.layout)
end

---open the overlay
function overlay:open()
    if not self.is_open then
        -- make sure that the most recently opened overlay is updated first
        for i = 1, #overlays do
            if overlays[i] == self then
                table.remove(overlays, i)
                break
            end
        end
        table.insert(overlays, 1, self)

        self.is_open = true
        self:update_layout()
        self.last_screen = keyboard_navigation.get_screen()
        keyboard_navigation.set_screen(self.layout)
        if self.transition then
            if not self.has_opened_before then
                self.has_opened_before = true
                self.transition.reset(self.layout)
            end
            self.transition.open(self.layout)
        end
        if self.backdrop then
            if self.transition then
                self.backdrop_alpha:keyframe(0.1, 0.7)
            else
                self.backdrop_alpha:set_immediate_value(0.7)
            end
        end
        if self.onopen then
            self.onopen()
        end
    end
end

---close the overlay
function overlay:close()
    if self.is_open then
        self.is_open = false
        -- only reset screen if it hasn't changed in the meantime
        if keyboard_navigation.get_screen() == self.layout then
            keyboard_navigation.set_screen(self.last_screen)
        end
        if self.transition then
            self.transition.close(self.layout)
        end
        if self.backdrop then
            if self.transition then
                self.backdrop_alpha:keyframe(0.1, 0)
            else
                self.backdrop_alpha:set_immediate_value(0)
            end
        end
        if self.onclose then
            self.onclose()
        end
    end
end

---set the gui scale of the overlay
---@param scale number
function overlay:set_scale(scale)
    self.layout:set_scale(scale)
end

---let the overlay process an event
---@param name string
---@param ... unknown
---@return boolean?
function overlay:process_event(name, ...)
    if self.is_open then
        if self.layout:process_event(name, ...) then
            return true
        end
        -- overlay closed during event processing, stop propagation
        if not self.is_open then
            return true
        end
        -- update keyboard navigation if overlay is focused
        if keyboard_navigation.get_screen() == self.layout then
            keyboard_navigation.process_event(name, ...)
        end
        if
            self.closable_by_outside_click
            and self.backdrop
            and not self.layout.is_mouse_over
            and name == "mousereleased"
        then
            self:close()
        end
        -- don't update stuff below if overlay is open
        return true
    end
end

---draw the overlay
function overlay:draw()
    if self.is_open or self.layout.transform:is_animating() then
        if self.backdrop and self.backdrop_alpha() ~= 0 then
            love.graphics.push()
            love.graphics.origin()
            love.graphics.setColor(0, 0, 0, self.backdrop_alpha())
            love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
            love.graphics.pop()
        end
        self.layout:draw()
    end
end

-- execute a function on all overlays with this metatable
overlay.overlays = setmetatable({}, {
    __index = function(_, fn)
        if fn == "draw" then
            return function(...)
                for i = #overlays, 1, -1 do
                    if overlays[i][fn](overlays[i], ...) then
                        return true
                    end
                end
                return false
            end
        else
            return function(...)
                for i = 1, #overlays do
                    if overlays[i][fn](overlays[i], ...) then
                        return true
                    end
                end
                return false
            end
        end
    end,
})

return overlay
