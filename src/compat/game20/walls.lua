local utils = require("compat.game192.utils")
local transform_hue = require("compat.game21.hue").transform
local extra_math = require("compat.game21.math")
local speed_data = require("compat.game20.speed_data")
local config = require("config")
local status = require("compat.game20.status")
local level_status = require("compat.game20.level_status")
local style = require("compat.game20.style")
local CENTER = { 0, 0 }
local SPAWN_DISTANCE = 1600
local black_and_white = false

local wall = {}
wall.__index = wall

function wall:new(hmod, side, thickness, speed, curve)
    side = utils.round_to_even(side or 0)
    thickness = thickness or 0
    local div = math.pi / level_status.sides
    local angle = div * 2 * side
    local verts = {}
    verts[1], verts[2] = extra_math.get_orbit(CENTER, angle - div, SPAWN_DISTANCE)
    verts[3], verts[4] = extra_math.get_orbit(CENTER, angle + div, SPAWN_DISTANCE)
    verts[5], verts[6] = extra_math.get_orbit(
        CENTER,
        angle + div + level_status.wall_angle_left,
        SPAWN_DISTANCE + thickness + level_status.wall_skew_left
    )
    verts[7], verts[8] = extra_math.get_orbit(
        CENTER,
        angle - div + level_status.wall_angle_right,
        SPAWN_DISTANCE + thickness + level_status.wall_skew_right
    )
    return setmetatable({
        speed = speed,
        curve = curve or speed_data:new(),
        hue_mod = hmod or 0,
        vertices = verts,
        must_be_removed = false,
    }, wall)
end

function wall:draw(quads, r, g, b, a)
    if self.hue_mod ~= 0 then
        r, g, b, a = transform_hue(self.hue_mod, r, g, b)
    end
    quads:add_quad(
        self.vertices[1],
        self.vertices[2],
        self.vertices[3],
        self.vertices[4],
        self.vertices[5],
        self.vertices[6],
        self.vertices[7],
        self.vertices[8],
        r,
        g,
        b,
        a
    )
end

function wall:update(frametime)
    self.speed:update(frametime)
    self.curve:update(frametime)
    local radius = status.radius * 0.65
    local points_on_center = 0
    for i = 1, 8, 2 do
        local x, y = self.vertices[i], self.vertices[i + 1]
        if math.abs(x) < radius and math.abs(y) < radius then
            points_on_center = points_on_center + 1
        else
            local move_distance = self.speed.speed * 5 * frametime
            local mag = math.sqrt(x ^ 2 + y ^ 2)
            x = x - x / mag * move_distance
            y = y - y / mag * move_distance
            local rot_ang = self.curve.speed / 60 * frametime
            local s, c = math.sin(rot_ang), math.cos(rot_ang)
            self.vertices[i] = x * c - y * s
            self.vertices[i + 1] = x * s + y * c
        end
    end
    if points_on_center > 3 then
        self.must_be_removed = true
    end
end

local walls = {
    entities = {},
}

function walls.init()
    black_and_white = config.get("black_and_white")
    walls.entities = {}
end

function walls.create(hmod, side, thickness, speed, curve)
    walls.entities[#walls.entities + 1] = wall:new(hmod, side, thickness, speed, curve)
end

function walls.update(frametime)
    for i = #walls.entities, 1, -1 do
        walls.entities[i]:update(frametime)
        if walls.entities[i].must_be_removed then
            table.remove(walls.entities, i)
        end
    end
end

function walls.draw(quads)
    local r, g, b, a = style.get_main_color()
    if black_and_white then
        r, g, b = 255, 255, 255
    end
    for i = 1, #walls.entities do
        walls.entities[i]:draw(quads, r, g, b, a)
    end
end

return walls
