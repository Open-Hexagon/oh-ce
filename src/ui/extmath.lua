local extmath = {}

-- The only useful constant from utils.lua
extmath.tau = 2 * math.pi

---sign function
---@param x number
---@return integer
function extmath.sgn(x)
    return x > 0 and 1 or x == 0 and 0 or -1
end

---clamp function
---@param t number
---@param a number
---@param b number
---@return number
function extmath.clamp(t, a, b)
    if t < a then
        return a
    end
    if t > b then
        return b
    end
    return t
end

do
    local alpha = 0.898204193266868
    local beta = 0.485968200201465
    ---Approximates sqrt(x * x + y * y)
    ---@param x number
    ---@param y number
    ---@return number
    function extmath.alpha_max_beta_min(x, y)
        x, y = math.abs(x), math.abs(y)
        local min, max
        if x < y then
            min, max = x, y
        else
            min, max = y, x
        end
        local z = alpha * max + beta * min
        if max < z then
            return z
        end
        return max
    end
end

---Linear interpolation between `a` and `b` with parameter `t`
---@param a number
---@param b number
---@param t number
---@return number
function extmath.lerp(a, b, t)
    return (1 - t) * a + t * b
end

---Inverse linear interpolation between `a` and `b` with parameter value `c`
---@param a number
---@param b number
---@param c number
---@return number
function extmath.inverse_lerp(a, b, c)
    return (c - a) / (b - a)
end

---Takes a value `t` between `a` and `b` and proportionally maps it to a value between `c` and `d`
---`a` != `b`
---@param t number
---@param a number
---@param b number
---@param c number
---@param d number
---@return number
function extmath.map(t, a, b, c, d)
    return c + ((d - c) / (b - a)) * (t - a)
end

function extmath.cubic_bezier(x0, y0, x1, y1, x2, y2, x3, y3, t)
    local u = 1 - t
    local uuu = u * u * u
    local uut3 = 3 * u * u * t
    local utt3 = 3 * u * t * t
    local ttt = t * t * t
    local x = uuu * x0 + uut3 * x1 + utt3 * x2 + ttt * x3
    local y = uuu * y0 + uut3 * y1 + utt3 * y2 + ttt * y3
    return x, y
end

---check if a given point is in a polygon
---@param vertices table
---@param x number
---@param y number
---@return boolean
function extmath.point_in_polygon(vertices, x, y)
    local result = false
    for i = 1, #vertices, 2 do
        local j = (i + 1) % #vertices + 1
        local x0, y0 = vertices[i], vertices[i + 1]
        local x1, y1 = vertices[j], vertices[j + 1]
        if (y0 > y) ~= (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0 then
            result = not result
        end
    end
    return result
end

return extmath
