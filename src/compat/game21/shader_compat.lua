local log = require("log")(...)
local shader_compat = {}

---this function translates a shader from the old game to work with love
---@param code string
---@param filename string
---@return table
function shader_compat.translate(code, filename)
    -- replace gl_ variables with love stuff
    code = [[
        vec4 _new_wrap_pixel_color;
        vec4 _new_wrap_original_pixel_color;
        vec2 _new_wrap_pixel_coord;
    ]] .. code:gsub("void main", "void _old_wrapped_main")
        :gsub("gl_FragCoord", "_new_wrap_pixel_coord")
        :gsub("gl_FragColor", "_new_wrap_pixel_color")
        :gsub("gl_TexCoord.0.", "VaryingTexCoord")
        :gsub("texture2D", "Texel")
        :gsub("texture", "Texel")
        :gsub("gl_Color", "_new_wrap_original_pixel_color") .. [[

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            _new_wrap_original_pixel_color = color;
            _new_wrap_pixel_coord = screen_coords;
            _new_wrap_pixel_coord.y = love_ScreenSize.y - _new_wrap_pixel_coord.y;
            #ifdef INITVARS
            _new_wrap_init_glob_vars();
            #endif
            _old_wrapped_main();
            #ifdef TEXT
            return _new_wrap_pixel_color * Texel(tex, VaryingTexCoord.xy);
            #else
            return _new_wrap_pixel_color;
            #endif
        }
    ]]
    -- remove lines starting with #version
    -- translate switch to if statements
    -- interpret layout(location = 0) out...
    -- get globals to initialize later
    local new_code = ""
    local block_depth = 0
    local need_to_initialize_later = {}
    local other_frag_color_name
    local in_switch, switch_var, switch_first
    for line in code:gmatch("([^\n]*)\n?") do
        line = line:gsub("\r", "")
        do
            local new_line = ""
            for i = 1, #line do
                if line:sub(i, i + 1) == "//" then
                    break
                end
                new_line = new_line .. line:sub(i, i)
            end
            line = new_line
        end
        local _, open_count = line:gsub("{", "")
        local _, close_count = line:gsub("}", "")
        block_depth = block_depth + open_count - close_count
        if line:gsub(" ", ""):match("switch%(") then
            in_switch = "waiting"
            switch_var = line:match("%((%a+)%)")
            switch_first = true
        end
        if in_switch == "waiting" then
            if line:match("{") then
                in_switch = block_depth
            end
            line = ""
        end
        if in_switch ~= nil and in_switch ~= "waiting" then
            if line:match("case") then
                if switch_first then
                    line = line:gsub("case", "if(" .. switch_var .. " =="):gsub(":", ") {")
                else
                    line = line:gsub("case", "} else if(" .. switch_var .. " =="):gsub(":", ") {")
                end
                switch_first = false
            elseif line:match("default") then
                line = line:gsub("default:", "} else {")
            end
            if block_depth == in_switch - 1 then
                in_switch = nil
            end
        end
        if block_depth == 0 and line:match("=") ~= nil then
            local new_line = ""
            for statement in line:gmatch("([^;]*);?") do
                local no_space_string = statement:gsub(" ", ""):gsub("\t", "")
                if no_space_string ~= "" then
                    if no_space_string:match("layout%(") ~= nil then
                        if no_space_string:match("location=0%)outvec4") ~= nil then
                            local index = no_space_string:find("4")
                            if index ~= nil then
                                other_frag_color_name = no_space_string:sub(index + 1)
                            end
                        end
                    else
                        local key, key_index
                        key_index = statement:find("=")
                        if key_index ~= nil then
                            key = statement:sub(1, key_index - 1)
                        end
                        if key == nil or key:match("const ") ~= nil then
                            new_line = new_line .. statement .. ";"
                        else
                            local value = statement:sub(key_index + 1)
                            need_to_initialize_later[#need_to_initialize_later + 1] = { key, value }
                            new_line = new_line .. key .. ";"
                        end
                    end
                end
            end
            line = new_line
        end
        local has_version = line:gsub(" ", ""):sub(1, 8) == "#version"
        if not has_version then
            new_code = new_code .. line .. "\n"
        end
    end
    if need_to_initialize_later[1] ~= nil then
        local add_to_top = "#define INITVARS\n\nvoid _new_wrap_init_glob_vars() {"
        for j = 1, #need_to_initialize_later do
            local variable, value = unpack(need_to_initialize_later[j])
            local space_index = 1
            local first = true
            for i = 1, #variable do
                if variable:sub(i, i) == " " then
                    if not first then
                        space_index = i
                        break
                    end
                else
                    first = false
                end
            end
            add_to_top = add_to_top .. "\n    " .. variable:sub(space_index + 1) .. "=" .. value .. ";"
        end
        add_to_top = add_to_top .. "\n}\n"
        new_code = new_code:gsub("vec4 effect%(", add_to_top .. "\nvec4 effect(")
    end
    if other_frag_color_name ~= nil then
        new_code = new_code:gsub("_new_wrap_pixel_color", other_frag_color_name)
    end
    return {
        code = code,
        new_code = new_code,
        filename = filename,
    }
end

---this function compiles a shader to work with the new rendering techniques used in this compat mode
---@param new_code any
---@param code any
---@param filename any
---@return table?
function shader_compat.compile(new_code, code, filename)
    local result
    xpcall(function()
        local shader = love.graphics.newShader(new_code)
        -- compile the shader a second time but with 3d layer offset instance code
        -- (since we don't know where the shader will be used yet and we don't wanted
        -- to slow down the game with runtime compilation)
        local instance_shader = love.graphics.newShader(
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
            ]]
                .. new_code:gsub(
                    "_new_wrap_original_pixel_color = color;",
                    "_new_wrap_original_pixel_color = instance_color_out;"
                )
        )
        -- store uniforms
        local uniforms = {}
        for line in code:gmatch("([^;]*);?") do
            local pos = line:find("uniform")
            if pos ~= nil then
                local uni_string = line:sub(pos + 8)
                local space_pos = uni_string:find(" ")
                local uni_name = uni_string:sub(space_pos + 1):match("%s*(.*)%s*")
                -- in case it was optimized out
                if shader:hasUniform(uni_name) then
                    local uni_type = uni_string:sub(1, space_pos - 1):match("%s*(.*)%s*")
                    uniforms[uni_name] = uni_type
                end
            end
        end
        result = {
            uniforms = uniforms,
            shader = shader,
            instance_shader = instance_shader,
            text_shader = love.graphics.newShader("#define TEXT\n" .. new_code),
        }
    end, function(msg)
        log("Failed compiling shader: '" .. filename .. "':\n" .. msg)
    end)
    return result
end

return shader_compat
