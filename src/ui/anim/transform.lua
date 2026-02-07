local signal = require("ui.anim.signal")
---@class animated_transform
---@field queue boolean
---@field translation table
---@field angle Queue
---@field scaling table
---@field transform love.Transform do not use this (use the :get method)
local transform = {}
transform.__index = transform

---create a new animated transform
---@param queue boolean? queue changes or stop animation and go to new keyframe
---@return table
function transform:new(queue)
    return setmetatable({
        queue = queue,
        translation = {
            x = signal.new_queue(0),
            y = signal.new_queue(0),
        },
        angle = signal.new_queue(0),
        scaling = {
            x = signal.new_queue(1),
            y = signal.new_queue(1),
        },
        transform = love.math.newTransform(),
    }, transform)
end

function transform:is_animating()
    return (
        self.translation.x.processing
        or self.translation.y.processing
        or self.angle.processing
        or self.scaling.x.processing
        or self.scaling.y.processing
    )
            and true
        or false
end

---scale things
---@param x number
---@param y number
---@param transition_time number
---@param easing function
function transform:scale(x, y, transition_time, easing)
    if not self.queue then
        self.scaling.x:stop()
        self.scaling.y:stop()
    end
    self.scaling.x:keyframe(transition_time or 0.1, x, easing)
    self.scaling.y:keyframe(transition_time or 0.1, y, easing)
end

---rotate things
---@param angle number
---@param transition_time number
---@param easing function
function transform:rotate(angle, transition_time, easing)
    if not self.queue then
        self.angle:stop()
    end
    self.angle:keyframe(transition_time or 0.1, angle, easing)
end

---translate things
---@param x number
---@param y number
---@param transition_time number
---@param easing function
function transform:translate(x, y, transition_time, easing)
    if not self.queue then
        self.translation.x:stop()
        self.translation.y:stop()
    end
    self.translation.x:keyframe(transition_time or 0.1, x, easing)
    self.translation.y:keyframe(transition_time or 0.1, y, easing)
end

---reset all transformations
---@param transition_time number
---@param easing function
function transform:reset(transition_time, easing)
    if not self.queue then
        self.translation.x:stop()
        self.translation.y:stop()
        self.scaling.x:stop()
        self.scaling.y:stop()
        self.angle:stop()
    end
    self.translation.x:keyframe(transition_time or 0.1, 0, easing)
    self.translation.y:keyframe(transition_time or 0.1, 0, easing)
    self.scaling.x:keyframe(transition_time or 0.1, 0, easing)
    self.scaling.y:keyframe(transition_time or 0.1, 0, easing)
    self.angle:keyframe(transition_time or 0.1, 0, easing)
end

---get a love transform object that represents the current state of the animation
---@return love.Transform
function transform:get()
    self.transform:reset()
    self.transform:translate(self.translation.x(), self.translation.y())
    self.transform:scale(self.scaling.x(), self.scaling.y())
    self.transform:rotate(self.angle())
    return self.transform
end

---inverse transform a point
---@param x number
---@param y number
---@return number
---@return number
function transform:inverseTransformPoint(x, y)
    return self:get():inverseTransformPoint(x, y)
end

---transform a point
---@param x number
---@param y number
---@return number
---@return number
function transform:transformPoint(x, y)
    return self:get():transformPoint(x, y)
end

---apply a love transform or an animated one
---@param transformation love.Transform|table
function transform.apply(transformation)
    if type(transformation) == "table" then
        love.graphics.applyTransform(transformation:get())
    else
        love.graphics.applyTransform(transformation)
    end
end

return transform
