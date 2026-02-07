local extmath = require("ui.extmath")

local ease = {}

-- These are easing functions, which are a special subset of math functions that help with specific transitions.
-- These output values from 0 to 1, and work best when paired with linear interpolation (lerp).
-- All formulas are referenced from easings.net.

function ease.linear(x)
    return x
end

---Returns a custom easing function that follows a quadradic bezier curve with points (0, 0), (x0, y0), (1, 1).
---@param x0 number
---@param y0 number
function ease.new_quad_bezier(x0, y0)
    if x0 == 0.5 then
        return function(t0)
            return 2 * (1 - t0) * t0 * y0 + t0 * t0
        end
    end
    x0 = extmath.clamp(x0, 0, 1)
    return function(t0)
        t0 = extmath.clamp(t0, 0, 1)
        local t = (math.sqrt(x0 * x0 + (1 - 2 * x0) * t0) - x0) / (1 - 2 * x0)
        return 2 * (1 - t) * t * y0 + t * t
    end
end

-- Sine
function ease.in_sine(x)
    return 1 - math.cos((extmath.clamp(x, 0, 1) * math.pi) / 2)
end

function ease.in_out_sine(x)
    return (1 - math.cos(math.pi * extmath.clamp(x, 0, 1))) / 2
end

function ease.out_sine(x)
    return math.sin((extmath.clamp(x, 0, 1) * math.pi) / 2)
end

-- Quadratic
function ease.in_quad(x)
    x = extmath.clamp(x, 0, 1)
    return x * x
end

function ease.in_out_quad(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and (2 * x * x) or (1 - (-2 * x + 2) ^ 2 / 2)
end

function ease.out_quad(x)
    x = 1 - extmath.clamp(x, 0, 1)
    return 1 - x * x
end

-- Cubic
function ease.in_cubic(x)
    x = extmath.clamp(x, 0, 1)
    return x * x * x
end

function ease.in_out_cubic(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and (4 * x * x * x) or (1 - (-2 * x + 2) ^ 3 / 2)
end

function ease.out_cubic(x)
    x = 1 - extmath.clamp(x, 0, 1)
    return 1 - x * x * x
end

-- Quartic
function ease.in_quart(x)
    x = extmath.clamp(x, 0, 1)
    return x * x * x * x
end

function ease.in_out_quart(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and (8 * x * x * x * x) or (1 - (-2 * x + 2) ^ 4 / 2)
end

function ease.out_quart(x)
    x = 1 - extmath.clamp(x, 0, 1)
    return 1 - x * x * x * x
end

-- Quintic
function ease.in_quint(x)
    x = extmath.clamp(x, 0, 1)
    return x * x * x * x * x
end

function ease.in_out_quint(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and (16 * x * x * x * x * x) or (1 - (-2 * x + 2) ^ 5 / 2)
end

function ease.out_quint(x)
    x = 1 - extmath.clamp(x, 0, 1)
    return 1 - x * x * x * x * x
end

-- Exponential
function ease.in_expo(x)
    x = extmath.clamp(x, 0, 1)
    return x == 0 and 0 or 2 ^ (10 * x - 10)
end

function ease.in_out_expo(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and (x == 0 and 0 or 2 ^ (20 * x - 10) / 2) or (x == 1 and 1 or (2 - 2 ^ (-20 * x + 10)) / 2)
end

-- Easings.net has this formula WRONG. This is the actual formula right here.
function ease.out_expo(x)
    x = extmath.clamp(x, 0, 1)
    return x == 1 and 1 or -2 ^ (-10 * x) + 1
end

-- Circle
function ease.in_circ(x)
    x = extmath.clamp(x, 0, 1)
    return 1 - math.sqrt(1 - x * x)
end

function ease.in_out_circ(x)
    x = 2 * extmath.clamp(x, 0, 1)
    return x < 1 and (1 - math.sqrt(1 - x * x)) / 2 or (math.sqrt(1 - (2 - x) ^ 2) + 1) / 2
end

function ease.out_circ(x)
    x = 1 - extmath.clamp(x, 0, 1)
    return math.sqrt(1 - x * x)
end

do
    -- Back Functions
    local A = 1.70158
    local B = A * 1.525
    local C = A + 1

    function ease.in_back(x)
        x = extmath.clamp(x, 0, 1)
        return C * x * x * x - A * x * x
    end

    function ease.in_out_back(x)
        x = 2 * extmath.clamp(x, 0, 1)
        return x < 1 and (x * x * ((B + 1) * x - B)) / 2 or ((x - 2) ^ 2 * ((B + 1) * (x - 2) + B) + 2) / 2
    end

    function ease.out_back(x)
        x = extmath.clamp(x, 0, 1) - 1
        return 1 + C * x * x * x + A * x * x
    end
end

-- Elastic
do
    local A = 2 * math.pi / 3
    local B = A / 1.5

    function ease.in_elastic(x)
        x = 10 * extmath.clamp(x, 0, 1)
        return x == 0 and 0 or (x == 10 and 1 or -(2 ^ (x - 10)) * math.sin((x - 10.75) * A))
    end

    function ease.in_out_elastic(x)
        x = 20 * extmath.clamp(x, 0, 1)
        return x < 10 and (x == 0 and 0 or -(2 ^ (x - 10)) * math.sin((x - 11.125) * B) / 2)
            or (x == 20 and 1 or 2 ^ (-x + 10) * math.sin((x - 11.125) * B) / 2 + 1)
    end

    function ease.out_elastic(x)
        x = 10 * extmath.clamp(x, 0, 1)
        return x == 0 and 0 or (x == 10 and 1 or 2 ^ -x * math.sin((x - 0.75) * A) + 1)
    end
end

-- Bounce
-- Okay. Easings.net has this completely wrong here. Their implementation is garbage.
-- This is a much better implementation (Thanks Oshisaure)
function ease.in_bounce(x, bounceFactor)
    bounceFactor = bounceFactor or 1 -- Optional parameter
    x = extmath.clamp(x, 0, 1)
    return x == 0 and 0 or math.abs(math.cos(bounceFactor * (1 - 1 / x) * math.pi) * math.sin(x * math.pi / 2) ^ 2)
end

function ease.in_out_bounce(x)
    x = extmath.clamp(x, 0, 1)
    return x < 0.5 and ease.in_bounce(x) or ease.out_bounce(x)
end

function ease.out_bounce(x, bounceFactor)
    x = extmath.clamp(x, 0, 1)
    return x == 1 and 1 or -ease.in_bounce(1 - x, bounceFactor) + 1
end

return ease
