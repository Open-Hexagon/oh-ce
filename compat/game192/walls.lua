local log = require("log")(...)
local utils = require("compat.game192.utils")
local module = {}

-- wall spawn distance in 1.92 cannot be changed
local WALL_SPAWN_DIST = 1600
local WALL_DESPAWN_DIST = 1600
local walls = {}
local duplicate_wall_count = 0
local tmp_wall_data = {}
local stopped_walls = {}
local imaginary_walls = 0
local stopped_wall_radius = math.huge
local level_data
local difficulty_mult
local need_to_check_stopped = false

function module.set_level_data(data, dm)
    level_data = data
    difficulty_mult = dm
end

-- need a custom function to replicate stupid conversion causing fractals to work
local to_radians_div = utils.float_round(57.3)
local function getOrbit(degrees, distance)
    return utils.float_round(math.cos((degrees / to_radians_div)) * distance),
        utils.float_round(math.sin((degrees / to_radians_div)) * distance)
end

function module.size()
    return #walls + #stopped_walls + imaginary_walls + duplicate_wall_count
end

local function spawn_wall(side, thickness, speed, acceleration, minSpeed, maxSpeed)
    side = utils.round_to_even(side)
    if thickness ~= thickness then
        log("Not spawning wall with NaN thickness!")
        return
    end
    local side_count = level_data.sides % 2 ^ 32
    local wall_angle_left = level_data.wall_angle_left
    local wall_angle_right = level_data.wall_angle_right
    local wall_skew_left = level_data.wall_skew_left
    local wall_skew_right = level_data.wall_skew_right
    local original_wall = utils.lookup_path(tmp_wall_data, {
        side_count,
        wall_angle_left,
        wall_angle_right,
        wall_skew_left,
        wall_skew_right,
        side,
        thickness,
        speed,
        acceleration,
        minSpeed,
        maxSpeed,
    })
    if original_wall ~= nil then
        original_wall.times = 1 + original_wall.times
        duplicate_wall_count = duplicate_wall_count + 1
    else
        local wall_table = {
            vertices = {},
            times = 1,
        }
        utils.insert_path(tmp_wall_data, {
            side_count,
            wall_angle_left,
            wall_angle_right,
            wall_skew_left,
            wall_skew_right,
            side,
            thickness,
            speed,
            acceleration,
            minSpeed,
            maxSpeed,
        }, wall_table)
        local div = utils.float_round(360 / side_count)
        local angle = div * side
        wall_table.vertices[7], wall_table.vertices[8] = getOrbit(angle - div * 0.5, WALL_SPAWN_DIST)
        wall_table.vertices[5], wall_table.vertices[6] = getOrbit(angle + div * 0.5, WALL_SPAWN_DIST)
        wall_table.vertices[3], wall_table.vertices[4] =
            getOrbit(angle + div * 0.5 + wall_angle_left, WALL_SPAWN_DIST + thickness + wall_skew_left)
        wall_table.vertices[1], wall_table.vertices[2] =
            getOrbit(angle - div * 0.5 + wall_angle_right, WALL_SPAWN_DIST + thickness + wall_skew_right)
        wall_table.speed = utils.float_round(speed)
        wall_table.accel = utils.float_round(acceleration)
        wall_table.minSpeed = utils.float_round(minSpeed)
        wall_table.maxSpeed = utils.float_round(maxSpeed)
        walls[#walls + 1] = wall_table
    end
end

function module.wallAcc(side, thickness, speedAdj, acceleration, minSpeed, maxSpeed)
    local speed_mult = level_data.speed_multiplier * math.pow(difficulty_mult, 0.65)
    spawn_wall(side, thickness, speedAdj * speed_mult, acceleration, minSpeed * speed_mult, maxSpeed * speed_mult)
end

function module.wallAdj(side, thickness, speedAdj)
    local speed_mult = level_data.speed_multiplier * math.pow(difficulty_mult, 0.65)
    spawn_wall(side, thickness, speedAdj * speed_mult, 0, 0, 0)
end

function module.wall(side, thickness)
    local speed_mult = level_data.speed_multiplier * math.pow(difficulty_mult, 0.65)
    spawn_wall(side, thickness, speed_mult, 0, 0, 0)
end

function module.clear()
    walls = {}
    duplicate_wall_count = 0
    tmp_wall_data = {}
    stopped_walls = {}
    imaginary_walls = 0
    stopped_wall_radius = math.huge
    need_to_check_stopped = false
end

function module.update(frametime, radius)
    tmp_wall_data = {}
    radius = radius * 0.65
    for i = #walls, 1, -1 do
        local moved_to_stopped = false
        local wall = walls[i]
        if wall.accel ~= 0 then
            wall.speed = wall.speed + wall.accel * frametime
            if wall.speed > wall.maxSpeed then
                wall.speed = wall.maxSpeed
            end
            if wall.speed < wall.minSpeed then
                wall.speed = wall.minSpeed
                if wall.minSpeed == 0 and wall.accel <= 0 then
                    moved_to_stopped = true
                    table.insert(stopped_walls, wall)
                    table.remove(walls, i)
                end
            end
        end
        local points_on_center = 0
        local points_out_of_bg = 0
        for j = 1, 8, 2 do
            local x, y = wall.vertices[j], wall.vertices[j + 1]
            local abs_x, abs_y = math.abs(x), math.abs(y)
            if moved_to_stopped then
                stopped_wall_radius = math.min(abs_x, abs_y, stopped_wall_radius)
            end
            if abs_x < radius and abs_y < radius then
                points_on_center = points_on_center + 1
            else
                local magnitude = math.sqrt(x ^ 2 + y ^ 2)
                local move_dist = wall.speed * 5 * frametime
                local new_x, new_y = x - x / magnitude * move_dist, y - y / magnitude * move_dist
                if ((new_x > 0) ~= (x > 0) or (new_y > 0) ~= (y > 0)) and wall.accel == 0 then
                    points_on_center = points_on_center + 1
                end
                wall.vertices[j] = new_x
                wall.vertices[j + 1] = new_y
                if abs_x > WALL_DESPAWN_DIST and abs_y > WALL_DESPAWN_DIST then
                    points_out_of_bg = points_out_of_bg + 1
                end
            end
        end
        if points_on_center > 3 or points_out_of_bg > 3 then
            duplicate_wall_count = duplicate_wall_count - wall.times + 1
            if points_out_of_bg > 3 then
                imaginary_walls = imaginary_walls + 1
                table.remove(walls, i)
            elseif not moved_to_stopped then
                table.remove(walls, i)
            end
        end
    end
    if stopped_wall_radius <= math.abs(radius) then
        stopped_wall_radius = math.huge
        for i = #stopped_walls, 1, -1 do
            local wall = stopped_walls[i]
            local points_on_center = 0
            local points_out_of_bg = 0
            for j = 1, 8, 2 do
                local x, y = wall.vertices[j], wall.vertices[j + 1]
                local abs_x, abs_y = math.abs(x), math.abs(y)
                if abs_x < radius and abs_y < radius then
                    points_on_center = points_on_center + 1
                elseif abs_x > WALL_DESPAWN_DIST and abs_y > WALL_DESPAWN_DIST then
                    points_out_of_bg = points_out_of_bg + 1
                end
                stopped_wall_radius = math.min(math.sqrt(abs_x ^ 2 + abs_y ^ 2), stopped_wall_radius)
            end
            need_to_check_stopped = true
            if points_on_center > 3 or points_out_of_bg > 3 then
                if points_out_of_bg > 3 then
                    imaginary_walls = imaginary_walls + 1
                end
                duplicate_wall_count = duplicate_wall_count - wall.times + 1
                table.remove(stopped_walls, i)
            end
        end
    end

    -- delete walls that were deleted for performance optimization when radius exceeds BGTileRadius
    -- may cause issues if far distant walls are not supposed to be deleted
    if radius > WALL_DESPAWN_DIST then
        imaginary_walls = 0
    end
end

-- iter over all walls that need collision checks
function module.iter()
    local index = 0
    return function()
        index = index + 1
        local wall = walls[index]
        if wall == nil and need_to_check_stopped then
            wall = stopped_walls[index - #walls]
        end
        return wall
    end
end

function module.draw(main_quads, r, g, b, a)
    for i = 1, #walls do
        local wall = walls[i]
        for _ = 1, wall.times do
            main_quads:add_quad(
                wall.vertices[1],
                wall.vertices[2],
                wall.vertices[3],
                wall.vertices[4],
                wall.vertices[5],
                wall.vertices[6],
                wall.vertices[7],
                wall.vertices[8],
                r,
                g,
                b,
                a
            )
        end
    end
    for i = 1, #stopped_walls do
        local wall = stopped_walls[i]
        for _ = 1, wall.times do
            main_quads:add_quad(
                wall.vertices[1],
                wall.vertices[2],
                wall.vertices[3],
                wall.vertices[4],
                wall.vertices[5],
                wall.vertices[6],
                wall.vertices[7],
                wall.vertices[8],
                r,
                g,
                b,
                a
            )
        end
    end
end

return module
