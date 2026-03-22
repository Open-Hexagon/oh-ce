local signal = require("ui2.anim.signal")
local settings = require("config").settings
local ohui = require("ohui")
local ui_settings = require("ohui").settings
local auto_gui_scale = require("ui2.auto_gui_scale")
local intercept_inputs = require("ui2.menu.settings").intercept_inputs

local ui2 = {}

function ui2.update()
    signal.update(love.timer.getDelta())
end

function ui2.process_event(name, a, b, c, d, e, f)
    if intercept_inputs(name, a, b, c, d, e, f) then
        ohui.push_event(name, a, b, c, d, e, f)
    end

    -- intercept the resize event for auto ui scaling
    if name == "resize" and settings.get("gui_scale") == 0 then
        ui_settings.scale = auto_gui_scale(a, b)
    end
end

return ui2
