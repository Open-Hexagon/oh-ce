local t = {}
local sin, cos = math.sin, math.cos

function t.get_orbit(start_pos, angle, distance, result)
    if result == nil then
        return start_pos[1] + cos(angle) * distance, start_pos[2] + sin(angle) * distance
    else
        result[1] = start_pos[1] + cos(angle) * distance
        result[2] = start_pos[2] + sin(angle) * distance
    end
end

function t.point_in_polygon(vertices, x, y)
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

function t.point_in_four_vertex_polygon(vertices, x, y)
    local ab_x = vertices[3] - vertices[1]
    local ab_y = vertices[4] - vertices[2]
    local bc_x = vertices[5] - vertices[3]
    local bc_y = vertices[6] - vertices[4]
    local cd_x = vertices[7] - vertices[5]
    local cd_y = vertices[8] - vertices[6]
    local da_x = vertices[1] - vertices[7]
    local da_y = vertices[2] - vertices[8]
    local ap_ab_x = x - vertices[1]
    local ap_ab_y = y - vertices[2]
    local bp_bc_x = x - vertices[3]
    local bp_bc_y = y - vertices[4]
    local cp_cd_x = x - vertices[5]
    local cp_cd_y = y - vertices[6]
    local dp_da_x = x - vertices[7]
    local dp_da_y = y - vertices[8]
    local ab_x_ap = ab_x * ap_ab_y - ab_y * ap_ab_x
    local bc_x_bp = bc_x * bp_bc_y - bc_y * bp_bc_x
    local cd_x_cp = cd_x * cp_cd_y - cd_y * cp_cd_x
    local da_x_dp = da_x * dp_da_y - da_y * dp_da_x
    return (ab_x_ap <= 0 and bc_x_bp <= 0 and cd_x_cp <= 0 and da_x_dp <= 0)
        or (ab_x_ap >= 0 and bc_x_bp >= 0 and cd_x_cp >= 0 and da_x_dp >= 0)
end

return t
