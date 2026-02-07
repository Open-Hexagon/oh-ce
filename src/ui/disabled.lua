return love.graphics.newShader([[
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = Texel(tex, texture_coords);
    color *= texturecolor;
    color.rgb *= 0.5;
    return color;
}
]])
