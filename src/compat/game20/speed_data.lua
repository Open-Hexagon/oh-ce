local utils = require("compat.game192.utils")
local speed_data = {}
speed_data.__index = speed_data

function speed_data:new(speed, accel, min, max, ping_pong)
    local obj = setmetatable({
        speed = speed or 0,
        accel = accel or 0,
        min = min or 0,
        max = max or 0,
        ping_pong = ping_pong or false,
    }, speed_data)
    for k, v in pairs(obj) do
        if type(v) == "number" then
            obj[k] = utils.float_round(v)
        end
    end
    return obj
end

function speed_data:update(frametime)
    if self.accel ~= 0 then
        self.speed = self.speed + self.accel * frametime
        if self.speed > self.max then
            self.speed = self.max
            if self.ping_pong then
                self.accel = -self.accel
            end
        end
        if self.speed < self.min then
            self.speed = self.min
            if self.ping_pong then
                self.accel = -self.accel
            end
        end
    end
end

return speed_data
