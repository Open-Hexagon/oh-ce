local make_make_accessors = require("compat.game21.lua_runtime.make_accessors")
local style = require("compat.game21.style")

return function(game)
    local pack = game.pack_data
    local lua_runtime = require("compat.game21.lua_runtime")
    local env = lua_runtime.env
    local make_accessors = make_make_accessors()
    make_accessors("s", "HueMin", style, "hue_min")
    make_accessors("s", "HueMax", style, "hue_max")
    make_accessors("s", "HueInc", style, "hue_increment")
    make_accessors("s", "HueIncrement", style, "hue_increment")
    make_accessors("s", "PulseMin", style, "pulse_min")
    make_accessors("s", "PulseMax", style, "pulse_max")
    make_accessors("s", "PulseInc", style, "pulse_increment")
    make_accessors("s", "PulseIncrement", style, "pulse_increment")
    make_accessors("s", "HuePingPong", style, "hue_ping_pong")
    make_accessors("s", "MaxSwapTime", style, "max_swap_time")
    make_accessors("s", "3dDepth", style, "pseudo_3D_depth")
    make_accessors("s", "3dSkew", style, "pseudo_3D_skew")
    make_accessors("s", "3dSpacing", style, "pseudo_3D_spacing")
    make_accessors("s", "3dDarkenMult", style, "pseudo_3D_darken_mult")
    make_accessors("s", "3dAlphaMult", style, "pseudo_3D_alpha_mult")
    make_accessors("s", "3dAlphaFalloff", style, "pseudo_3D_alpha_falloff")
    make_accessors("s", "3dPulseMax", style, "pseudo_3D_pulse_max")
    make_accessors("s", "3dPulseMin", style, "pseudo_3D_pulse_min")
    make_accessors("s", "3dPulseSpeed", style, "pseudo_3D_pulse_speed")
    make_accessors("s", "3dPerspectiveMult", style, "pseudo_3D_perspective_mult")
    make_accessors("s", "BGTileRadius", style, "bg_tile_radius")
    make_accessors("s", "BGColorOffset", style, "bg_color_offset")
    make_accessors("s", "BGRotationOffset", style, "bg_rot_off")
    env.s_setCapColorMain = function()
        style.set_cap_color(1)
    end
    env.s_setCapColorMainDarkened = function()
        style.set_cap_color(2)
    end
    env.s_setCapColorByIndex = function(index)
        index = index or 0
        style.set_cap_color(4 + index)
    end
    env.s_getMainColor = function()
        return style.get_main_color()
    end
    env.s_getPlayerColor = function()
        return style.get_player_color()
    end
    env.s_getTextColor = function()
        return style.get_text_color()
    end
    env.s_get3DOverrideColor = function()
        return style.get_3D_override_color()
    end
    env.s_getCapColorResult = function()
        return style.get_cap_color_result()
    end
    env.s_getColor = function(index)
        return style.get_color(index)
    end
    env.s_setStyle = function(style_id)
        local style_data = pack.styles[tostring(style_id)]
        if style_data == nil then
            lua_runtime.error("Trying to load an invalid style '" .. style_id .. "'")
        else
            style.select(style_data)
            style.compute_colors()
        end
    end
end
