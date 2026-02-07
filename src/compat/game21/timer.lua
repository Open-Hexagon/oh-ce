local timer = {}
timer.__index = timer

function timer:new(time, running)
    if running == nil then
        running = true
    end
    return setmetatable({
        time = time,
        running = running,
        current = 0,
        total = 0,
        ticks = 0,
        loop = true,
    }, timer)
end

function timer:update(frametime, target)
    self.time = target or self.time
    local increment = self.running and frametime or 0
    self.current = self.current + increment
    self.total = self.total + increment
    if self.current < self.time then
        return false
    end
    self.ticks = self.ticks + 1
    self:reset_current()
    self.running = self.loop
    return true
end

function timer:pause()
    self.running = false
end

function timer:resume()
    self.running = true
end

function timer:stop()
    self:reset_current()
    self:pause()
end

function timer:restart(target)
    self.time = target or self.time
    self:reset_current()
    self:resume()
end

function timer:reset_current()
    self.current = 0
end

function timer:reset_ticks()
    self.ticks = 0
end

function timer:reset_total()
    self.total = 0
end

function timer:reset_all()
    self:reset_current()
    self:reset_ticks()
    self:reset_total()
end

function timer:set_loop(bool)
    self.loop = bool
end

return timer
