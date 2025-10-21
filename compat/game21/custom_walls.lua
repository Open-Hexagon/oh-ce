local extra_math = require("compat.game21.math")
local custom_walls = {}
local free_handles = {}
local cws = {}
local highest_handle = 0

local function create_cw(deadly, collision)
    local handle
    if #free_handles == 0 then
        local reserve_size = 32 + highest_handle * 2
        highest_handle = highest_handle + reserve_size
        for i = 1, reserve_size do
            free_handles[#free_handles + 1] = highest_handle - i + 1
        end
    end
    handle = free_handles[1]
    table.remove(free_handles, 1)
    highest_handle = math.max(highest_handle, handle)
    custom_walls[handle] = custom_walls[handle] or {}
    local cw = custom_walls[handle]
    cw.visible = true
    cw.old_vertices = cw.old_vertices or { 0, 0, 0, 0, 0, 0, 0, 0 }
    cw.vertices = cw.vertices or { 0, 0, 0, 0, 0, 0, 0, 0 }
    cw.colors = cw.colors or { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
    cw.collision = collision
    cw.deadly = deadly
    cw.killing_side = 0
    return handle - 1
end
cws.cw_create = function()
    return create_cw(false, true)
end
cws.cw_createDeadly = function()
    return create_cw(true, true)
end
cws.cw_createNoCollision = function()
    return create_cw(false, false)
end
local function process_handle(handle)
    handle = (handle or 0) + 1
    if custom_walls[handle] == nil then
        error("Trying to access invalid cw handle: " .. handle)
    end
    return handle
end
cws.cw_destroy = function(handle)
    handle = process_handle(handle)
    custom_walls[handle].visible = false
    free_handles[#free_handles + 1] = handle
end
cws.cw_setVertexPos = function(handle, vertex, x, y)
    handle = process_handle(handle)
    custom_walls[handle].vertices[vertex * 2 + 1] = x or 0
    custom_walls[handle].vertices[vertex * 2 + 2] = y or 0
end
cws.cw_moveVertexPos = function(handle, vertex, offset_x, offset_y)
    handle = process_handle(handle)
    custom_walls[handle].vertices[vertex * 2 + 1] = custom_walls[handle].vertices[vertex * 2 + 1] + (offset_x or 0)
    custom_walls[handle].vertices[vertex * 2 + 2] = custom_walls[handle].vertices[vertex * 2 + 2] + (offset_y or 0)
end
cws.cw_moveVertexPos4Same = function(handle, offset_x, offset_y)
    handle = process_handle(handle)
    custom_walls[handle].vertices[1] = custom_walls[handle].vertices[1] + (offset_x or 0)
    custom_walls[handle].vertices[2] = custom_walls[handle].vertices[2] + (offset_y or 0)
    custom_walls[handle].vertices[3] = custom_walls[handle].vertices[3] + (offset_x or 0)
    custom_walls[handle].vertices[4] = custom_walls[handle].vertices[4] + (offset_y or 0)
    custom_walls[handle].vertices[5] = custom_walls[handle].vertices[5] + (offset_x or 0)
    custom_walls[handle].vertices[6] = custom_walls[handle].vertices[6] + (offset_y or 0)
    custom_walls[handle].vertices[7] = custom_walls[handle].vertices[7] + (offset_x or 0)
    custom_walls[handle].vertices[8] = custom_walls[handle].vertices[8] + (offset_y or 0)
end
cws.cw_setVertexColor = function(handle, vertex, r, g, b, a)
    handle = process_handle(handle)
    custom_walls[handle].colors[vertex * 4 + 1] = r or 0
    custom_walls[handle].colors[vertex * 4 + 2] = g or 0
    custom_walls[handle].colors[vertex * 4 + 3] = b or 0
    custom_walls[handle].colors[vertex * 4 + 4] = a or 0
end
cws.cw_setVertexPos4 = function(handle, x0, y0, x1, y1, x2, y2, x3, y3)
    handle = process_handle(handle)
    custom_walls[handle].vertices[1] = x0 or 0
    custom_walls[handle].vertices[2] = y0 or 0
    custom_walls[handle].vertices[3] = x1 or 0
    custom_walls[handle].vertices[4] = y1 or 0
    custom_walls[handle].vertices[5] = x2 or 0
    custom_walls[handle].vertices[6] = y2 or 0
    custom_walls[handle].vertices[7] = x3 or 0
    custom_walls[handle].vertices[8] = y3 or 0
end
cws.cw_setVertexColor4 = function(handle, r0, g0, b0, a0, r1, g1, b1, a1, r2, g2, b2, a2, r3, g3, b3, a3)
    handle = process_handle(handle)
    custom_walls[handle].colors[1] = r0 or 0
    custom_walls[handle].colors[2] = g0 or 0
    custom_walls[handle].colors[3] = b0 or 0
    custom_walls[handle].colors[4] = a0 or 0
    custom_walls[handle].colors[5] = r1 or 0
    custom_walls[handle].colors[6] = g1 or 0
    custom_walls[handle].colors[7] = b1 or 0
    custom_walls[handle].colors[8] = a1 or 0
    custom_walls[handle].colors[9] = r2 or 0
    custom_walls[handle].colors[10] = g2 or 0
    custom_walls[handle].colors[11] = b2 or 0
    custom_walls[handle].colors[12] = a2 or 0
    custom_walls[handle].colors[13] = r3 or 0
    custom_walls[handle].colors[14] = g3 or 0
    custom_walls[handle].colors[15] = b3 or 0
    custom_walls[handle].colors[16] = a3 or 0
end
cws.cw_setVertexColor4Same = function(handle, r, g, b, a)
    handle = process_handle(handle)
    for i = 0, 3 do
        custom_walls[handle].colors[i * 4 + 1] = r or 0
        custom_walls[handle].colors[i * 4 + 2] = g or 0
        custom_walls[handle].colors[i * 4 + 3] = b or 0
        custom_walls[handle].colors[i * 4 + 4] = a or 0
    end
end
cws.cw_setCollision = function(handle, collision)
    handle = process_handle(handle)
    custom_walls[handle].collision = collision
end
cws.cw_setDeadly = function(handle, deadly)
    handle = process_handle(handle)
    custom_walls[handle].deadly = deadly
end
cws.cw_setKillingSide = function(handle, side)
    handle = process_handle(handle)
    custom_walls[handle].killing_side = side
end
cws.cw_getCollision = function(handle)
    handle = process_handle(handle)
    return custom_walls[handle].collision
end
cws.cw_getDeadly = function(handle)
    handle = process_handle(handle)
    return custom_walls[handle].deadly
end
cws.cw_getKillingSide = function(handle)
    handle = process_handle(handle)
    return custom_walls[handle].killing_side
end
cws.cw_getVertexPos = function(handle, vertex)
    handle = process_handle(handle)
    return custom_walls[handle].vertices[vertex * 2 + 1], custom_walls[handle].vertices[vertex * 2 + 2]
end
cws.cw_getVertexPos4 = function(handle)
    handle = process_handle(handle)
    return custom_walls[handle].vertices[1],
        custom_walls[handle].vertices[2],
        custom_walls[handle].vertices[3],
        custom_walls[handle].vertices[4],
        custom_walls[handle].vertices[5],
        custom_walls[handle].vertices[6],
        custom_walls[handle].vertices[7],
        custom_walls[handle].vertices[8]
end
cws.cw_clear = function()
    custom_walls = {}
    free_handles = {}
    highest_handle = 0
end
function cws.iter()
    local index = 0
    return function()
        index = index + 1
        while custom_walls[index] == nil or not custom_walls[index].visible do
            index = index + 1
            if index > highest_handle then
                return
            end
        end
        return custom_walls[index]
    end
end

function cws.handle_collision(movement, radius, player, frametime)
    local radius_squared = radius ^ 2
    do
        local collided
        for cw in cws.iter() do
            if cw.collision and extra_math.point_in_polygon(cw.vertices, player:get_position()) then
                if
                    player.get_just_swapped()
                    or cw.deadly
                    or player.cw_push(movement, radius, cw, radius_squared, frametime)
                then
                    return true
                end
                collided = true
            end
        end
        if not collided then
            return false
        end
    end
    do
        local collided
        for cw in cws.iter() do
            if cw.collision and extra_math.point_in_polygon(cw.vertices, player:get_position()) then
                if player.cw_push(movement, radius, cw, radius_squared, frametime) then
                    return true
                end
                collided = true
            end
        end
        if not collided then
            return false
        end
    end
    local p_pos_x, p_pos_y = player:get_position()
    for cw in cws.iter() do
        if cw.collision and extra_math.point_in_polygon(cw.vertices, p_pos_x, p_pos_y) then
            return true
        end
    end
    return false
end

function cws.update_old_vertices()
    for cw in cws.iter() do
        if cw.collision then
            for i = 1, 8 do
                cw.old_vertices[i] = cw.vertices[i]
            end
        end
    end
end

function cws.draw(wall_quads)
    for cw in cws.iter() do
        wall_quads:add_quad(
            cw.vertices[1],
            cw.vertices[2],
            cw.vertices[3],
            cw.vertices[4],
            cw.vertices[5],
            cw.vertices[6],
            cw.vertices[7],
            cw.vertices[8],
            unpack(cw.colors)
        )
    end
end
return cws
