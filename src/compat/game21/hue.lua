local hue = {}

function hue.get_color(h, color)
    local i = math.floor(h * 6)

    local f = (h * 6) - i
    local q = 1 - f
    local t = f

    local function ret(r, g, b)
        color[1] = r * 255
        color[2] = g * 255
        color[3] = b * 255
        color[4] = 255
    end

    if i == 0 then
        ret(1, t, 0)
    elseif i == 1 then
        ret(q, 1, 0)
    elseif i == 2 then
        ret(0, 1, t)
    elseif i == 3 then
        ret(0, q, 1)
    elseif i == 4 then
        ret(t, 0, 1)
    else
        ret(1, 0, q)
    end
end

function hue.transform(h, r, g, b)
    -- using 3.14 instead of pi for parity with the OH code
    local u = math.cos(h * 3.14 / 180)
    local w = math.sin(h * 3.14 / 180)
    local function to_uint8(num)
        -- emulates exactly how the game rounds and limits the numbers
        -- just using math.floor or math.floor with +0.5 resulted in
        -- an underflow on g-force making the walls blue instead of black
        local sign = num > 0 and 1 or -1
        return (math.floor(math.abs(num)) * sign) % 256
    end
    return to_uint8((0.701 * u + 0.168 * w) * r + (-0.587 * u + 0.330 * w) * g + (-0.114 * u - 0.497 * w) * b),
        to_uint8((-0.299 * u - 0.328 * w) * r + (0.413 * u + 0.035 * w) * g + (-0.114 * u + 0.292 * w) * b),
        to_uint8((-0.3 * u + 1.25 * w) * r + (-0.588 * u - 1.05 * w) * g + (0.886 * u - 0.203 * w) * b),
        255
end

return hue
