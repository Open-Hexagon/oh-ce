local ui = require("ohui")
local tau = require("ui2.extmath").tau
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")

local function angle_waveform(x)
    return tau * signal.sawtooth(x)
end

local angle = signal.new_waveform(0.15, angle_waveform)
local sides = signal.new_queue(6)

local A = 0.1
local B = 0.7

local function side_loop()
    local old_sides = sides()
    local new_sides = ((old_sides - 3) + math.random(1, 5)) % 6 + 3
    angle:set_progress(angle:get_progress() + (1 / old_sides) * math.random(1, old_sides))
    sides:keyframe(A * math.abs(new_sides - old_sides), new_sides, ease.in_out_sine)
    sides:wait(B)
    sides:call(side_loop)
end

local points = {}

local loading_spinner = {}

---starts the spinner animation
function loading_spinner.start()
    angle:resume()
    sides:resume()
    angle:set_progress(0)
    sides:set_immediate_value(6)
    side_loop()
end

---stops the spinner animation
function loading_spinner.stop()
    angle:suspend()
    sides:suspend()
    sides:stop()
end

---spinner element
---@param x number
---@param y number
---@param radius number
---@param line_width number
function loading_spinner.element(x, y, radius, line_width)
    local point_count = math.ceil(sides())
    local step = tau / sides()
    for i = 0, point_count - 1 do
        points[i * 2 + 1] = radius * math.cos(step * i + angle()) + x
        points[i * 2 + 2] = radius * math.sin(step * i + angle()) + y
    end
    ui.draw.by_value.polygon("line", { 1, 1, 1, 1 }, line_width, unpack(points, 1, point_count * 2))
end

return loading_spinner
