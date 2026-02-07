local args = require("args")
local utils = require("compat.game192.utils")
local config = require("config")
local status = require("compat.game21.status")
local style = require("compat.game21.style")
local pseudo3d = {}
local game, layer_shader
local layer_offsets = {}
local pivot_layer_colors = {}
local wall_layer_colors = {}
local player_layer_colors = {}

function pseudo3d.init(pass_game)
    if not args.headless then
        layer_shader = love.graphics.newShader(
            [[
                layout(location = 3) in vec2 instance_position;
                layout(location = 4) in vec4 instance_color;
                out vec4 instance_color_out;

                vec4 position(mat4 transform_projection, vec4 vertex_position)
                {
                    instance_color_out = instance_color / 255.0;
                    vertex_position.xy += instance_position;
                    return transform_projection * vertex_position;
                }
            ]],
            [[
                in vec4 instance_color_out;

                vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
                {
                    return instance_color_out;
                }
            ]]
        )
    end
    game = pass_game
end

function pseudo3d.update(frametime)
    status.pulse3D =
        utils.float_round(status.pulse3D + style.pseudo_3D_pulse_speed * status.pulse3D_direction * frametime)
    if status.pulse3D > style.pseudo_3D_pulse_max then
        status.pulse3D_direction = -1
    elseif status.pulse3D < style.pseudo_3D_pulse_min then
        status.pulse3D_direction = 1
    end
end

local depth, pulse_3d, effect, rad_rot, sin_rot, cos_rot

function pseudo3d.apply_skew()
    if config.get("3D_enabled") then
        depth = style.pseudo_3D_depth
        pulse_3d = config.get("pulse") and status.pulse3D or 1
        effect = style.pseudo_3D_skew * pulse_3d * config.get("3D_multiplier")
        rad_rot = math.rad(game.current_rotation + 90)
        sin_rot = math.sin(rad_rot)
        cos_rot = math.cos(rad_rot)
        love.graphics.scale(1, 1 / (1 + effect))
    end
end

local function adjust_alpha(a, i)
    if style.pseudo_3D_alpha_mult == 0 then
        return a
    end
    local new_alpha = (a / style.pseudo_3D_alpha_mult) - i * style.pseudo_3D_alpha_falloff
    if new_alpha > 255 then
        return 255
    elseif new_alpha < 0 then
        return 0
    end
    return new_alpha
end

function pseudo3d.draw(set_render_stage, wall_quads, pivot_quads, player_tris, black_and_white)
    if config.get("3D_enabled") then
        for j = 1, depth do
            local i = depth - j
            local offset = style.pseudo_3D_spacing * (i + 1) * style.pseudo_3D_perspective_mult * effect * 3.6 * 1.4
            layer_offsets[j] = layer_offsets[j] or {}
            layer_offsets[j][1] = offset * cos_rot
            layer_offsets[j][2] = offset * sin_rot
            local r, g, b, a = style.get_3D_override_color()
            if black_and_white then
                r, g, b = 255, 255, 255
                style.pseudo_3D_override_is_main = false
            end
            r = r / style.pseudo_3D_darken_mult
            g = g / style.pseudo_3D_darken_mult
            b = b / style.pseudo_3D_darken_mult
            a = adjust_alpha(a, i)
            pivot_layer_colors[j] = pivot_layer_colors[j] or {}
            pivot_layer_colors[j][1] = r
            pivot_layer_colors[j][2] = g
            pivot_layer_colors[j][3] = b
            pivot_layer_colors[j][4] = a
            if style.pseudo_3D_override_is_main then
                r, g, b, a = style.get_wall_color()
                r = r / style.pseudo_3D_darken_mult
                g = g / style.pseudo_3D_darken_mult
                b = b / style.pseudo_3D_darken_mult
                a = adjust_alpha(a, i)
            end
            wall_layer_colors[j] = wall_layer_colors[j] or {}
            wall_layer_colors[j][1] = r
            wall_layer_colors[j][2] = g
            wall_layer_colors[j][3] = b
            wall_layer_colors[j][4] = a
            if style.pseudo_3D_override_is_main then
                r, g, b, a = style.get_player_color()
                r = r / style.pseudo_3D_darken_mult
                g = g / style.pseudo_3D_darken_mult
                b = b / style.pseudo_3D_darken_mult
                a = adjust_alpha(a, i)
            end
            player_layer_colors[j] = player_layer_colors[j] or {}
            player_layer_colors[j][1] = r
            player_layer_colors[j][2] = g
            player_layer_colors[j][3] = b
            player_layer_colors[j][4] = a
        end
        if depth > 0 then
            wall_quads:set_instance_attribute_array("instance_position", "floatvec2", 3, layer_offsets)
            wall_quads:set_instance_attribute_array("instance_color", "floatvec4", 4, wall_layer_colors)
            pivot_quads:set_instance_attribute_array("instance_position", "floatvec2", 3, layer_offsets)
            pivot_quads:set_instance_attribute_array("instance_color", "floatvec4", 4, pivot_layer_colors)
            player_tris:set_instance_attribute_array("instance_position", "floatvec2", 3, layer_offsets)
            player_tris:set_instance_attribute_array("instance_color", "floatvec4", 4, player_layer_colors)

            set_render_stage(1, layer_shader, true)
            wall_quads:draw_instanced(depth)
            set_render_stage(2, layer_shader, true)
            pivot_quads:draw_instanced(depth)
            set_render_stage(3, layer_shader, true)
            player_tris:draw_instanced(depth)
        end
    end
end

return pseudo3d
