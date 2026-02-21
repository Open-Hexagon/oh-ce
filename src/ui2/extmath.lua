---A bunch of more niche math functions.
local extmath = {}

---the only useful constant from utils.lua.
extmath.tau = 2 * math.pi

---sign function
---@param x number
---@return integer
---@nodiscard
function extmath.sgn(x)
    return x > 0 and 1 or x == 0 and 0 or -1
end

---clamp function
---@param t number
---@param a number
---@param b number
---@return number
---@nodiscard
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
    ---Approximates sqrt(x * x + y * y), though not very well.
    ---@param x number
    ---@param y number
    ---@return number
    ---@nodiscard
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

---Linear interpolation between `a` and `b` with parameter `t`.
---@param a number
---@param b number
---@param t number
---@return number
---@nodiscard
function extmath.lerp(a, b, t)
    return (1 - t) * a + t * b
end

---Inverse linear interpolation between `a` and `b` with parameter value `c`.
---@param a number
---@param b number
---@param c number
---@return number
---@nodiscard
function extmath.inverse_lerp(a, b, c)
    return (c - a) / (b - a)
end

---Takes a value `t` between `a` and `b` and proportionally maps it to a value between `c` and `d`.
---`a` != `b`.
---@param t number
---@param a number
---@param b number
---@param c number
---@param d number
---@return number
---@nodiscard
function extmath.map(t, a, b, c, d)
    return c + ((d - c) / (b - a)) * (t - a)
end

---Cubic bezier function
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param x3 number
---@param y3 number
---@param t number
---@return number
---@return number
---@nodiscard
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
---@nodiscard
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

---Gets the inradius of a regular polygon from its radius and number of sides.
---The inradius of a regular polygon is the distance from its center to the midpoint of a side.
---@param r number radius
---@param n integer number of sides
---@return number
---@nodiscard
function extmath.to_inradius(r, n)
    return r * math.cos(math.pi / n)
end

---Gets the radius of a regular polygon from its inradius and number of sides.
---The inradius of a regular polygon is the distance from its center to the midpoint of a side.
---@param a number inradius
---@param n integer number of sides
---@return number
---@nodiscard
function extmath.from_inradius(a, n)
    return a / math.cos(math.pi / n)
end

---Returns a new regular polygon radius by applying an offset to what its inradius would be.
---@param r number regular polygon radius
---@param n any number of sides
---@param o any offset
---@return number
---@nodiscard
function extmath.inradius_offset(r, n, o)
    return r + o / math.cos(math.pi / n)
end

---Returns true if (x, y) is inside the aligned rectangle.
---@param x number
---@param y number
---@param left number
---@param right number
---@param top number
---@param bottom number
---@return boolean
---@nodiscard
function extmath.point_in_aligned_rectangle(x, y, left, top, right, bottom)
    return x >= left and x < right and y >= top and y < bottom
end

---Get the intersection of two aligned rectangles. Returns nil if there was no intersection.
---@param x1 number rectangle 1 coordinate 1
---@param y1 number rectangle 1 coordinate 1
---@param x2 number rectangle 1 coordinate 2
---@param y2 number rectangle 1 coordinate 2
---@param x3 number rectangle 2 coordinate 1
---@param y3 number rectangle 2 coordinate 1
---@param x4 number rectangle 2 coordinate 2
---@param y4 number rectangle 2 coordinate 2
---@return number? x_inter1 output rectangle coordinate 1, nil if there was no intersection
---@return number y_inter1 output rectangle coordinate 1
---@return number x_inter2 output rectangle coordinate 2
---@return number y_inter2 output rectangle coordinate 2
---@nodiscard
function extmath.aligned_rectangle_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
    -- Calculate the coordinates of the intersection rectangle
    local x_inter1 = math.max(x1, x3)
    local y_inter1 = math.max(y1, y3)
    local x_inter2 = math.min(x2, x4)
    local y_inter2 = math.min(y2, y4)

    -- Check if there is an intersection
    if x_inter1 < x_inter2 and y_inter1 < y_inter2 then
        return x_inter1, y_inter1, x_inter2, y_inter2
    else
        return nil, 0, 0, 0 -- No intersection
    end
end

---rounds a number
---@param n number number
---@param p integer number of decimal places
---@return number
---@nodiscard
function extmath.round(n, p)
    local exp = 10 ^ p
    return math.floor(n * exp + 0.5) / exp
end

return extmath
