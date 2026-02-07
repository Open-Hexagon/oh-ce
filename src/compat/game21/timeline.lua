local timeline = {}
timeline.__index = timeline

function timeline:new()
    return setmetatable({
        _actions = {},
        _current_index = 1,
    }, timeline)
end

function timeline:clear(no_reset_index)
    self._actions = {}
    if not no_reset_index then
        self._current_index = 1
    end
end

function timeline:append_do(func)
    self._actions[#self._actions + 1] = function()
        func()
        return true
    end
end

function timeline:append_wait_for(duration)
    local wait_start_tp
    self._actions[#self._actions + 1] = function(time_point)
        if wait_start_tp == nil then
            wait_start_tp = time_point
        end
        local elapsed = time_point - wait_start_tp
        return elapsed >= duration
    end
end

function timeline:append_wait_for_seconds(seconds)
    self:append_wait_for(math.floor(seconds * 1000))
end

function timeline:append_wait_for_sixths(sixths)
    self:append_wait_for_seconds(sixths / 60)
end

function timeline:append_wait_until(target_time_point)
    self._actions[#self._actions + 1] = function(time_point)
        return time_point >= target_time_point
    end
end

function timeline:append_wait_until_fn(time_point_func)
    self._actions[#self._actions + 1] = function(time_point)
        return time_point >= time_point_func()
    end
end

function timeline:size()
    return #self._actions
end

function timeline:update(time_point)
    if self._current_index > self:size() then
        -- timeline done
        return true
    end
    while self._current_index <= self:size() do
        if not self._actions[self._current_index](time_point) then
            -- action not done, need to wait
            return false
        end
        self._current_index = self._current_index + 1
    end
    -- timeline done
    return true
end

return timeline
