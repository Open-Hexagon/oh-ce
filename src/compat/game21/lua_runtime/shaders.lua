local args = require("args")
local log = require("log")(...)
local status = require("compat.game21.status")
local assets = require("asset_system")

local M = {}

local shaders
local loaded_filenames

local function get_shader_id(pack_data, filename)
    local loaded_pack_shaders = loaded_filenames[pack_data.info.path]
    if loaded_pack_shaders ~= nil and loaded_pack_shaders[filename] ~= nil then
        return loaded_pack_shaders[filename]
    else
        local shader = pack_data.shaders[filename]
        if shader then
            local id = #shaders + 1
            shaders[id] = shader
            loaded_filenames[pack_data.info.path] = loaded_filenames[pack_data.info.path] or {}
            loaded_filenames[pack_data.info.path][filename] = id
            return id
        end
    end
    require("compat.game21.lua_runtime").error("Shader '" .. filename .. "' does not exist!")
    return -1
end

local function check_valid_shader_id(id)
    if args.headless then
        return false
    end
    if id < 1 or id > #shaders then
        log("Invalid shader id: '" .. id .. "'")
        return false
    end
    return true
end

local uniform_values

local function set_uniform(id_or_shader, uniform_type, name, value)
    local shader = id_or_shader
    if type(shader) == "number" and check_valid_shader_id(shader or -1) then
        shader = shaders[shader or -1]
    end
    if type(shader) == "table" then
        local shader_type = shader.uniforms[name]
        -- would be nil if uniform didn't exist (not printing errors because of spam)
        if shader_type ~= nil then
            if shader_type == uniform_type then
                if assets.is_hot_reloading then
                    -- store uniforms when hot reloading
                    uniform_values[shader] = uniform_values[shader] or {}
                    uniform_values[shader][name] = uniform_values[shader][name] or {}
                    local value_table = uniform_values[shader][name]
                    value_table.type = uniform_type
                    if type(value) == "table" then
                        -- copy table values (since tables are reused when setting uniforms)
                        if type(value_table.value) == "table" then
                            for i = 1, math.max(#value, #value_table.value) do
                                value_table.value[i] = value[i]
                            end
                        else
                            value_table.value = { unpack(value) }
                        end
                    else
                        value_table.value = value
                    end
                end
                shader.shader:send(name, value)
                shader.instance_shader:send(name, value)
                shader.text_shader:send(name, value)
            else
                require("compat.game21.lua_runtime").error(
                    ("Uniform '%s': type '%s' does not match the type in the shader '%s'"):format(
                        name,
                        uniform_type,
                        shader_type
                    )
                )
            end
        end
    end
end

local last_shader_tables = {}
local last_shader_userdata = {}

---check if shaders changed
function M.check()
    if assets.is_hot_reloading then
        for i = 0, 8 do
            if
                last_shader_tables[i] ~= nil
                and last_shader_tables[i] == status.fragment_shaders[i]
                and last_shader_userdata[i] ~= status.fragment_shaders[i].shader
            then
                -- shader changed, reapply uniforms
                local shader = last_shader_tables[i]
                for uname, uvalue in pairs(uniform_values[shader]) do
                    set_uniform(shader, uvalue.type, uname, uvalue.value)
                end
            end
        end
        for i = 0, 8 do
            last_shader_tables[i] = status.fragment_shaders[i]
            if last_shader_tables[i] ~= nil then
                last_shader_userdata[i] = status.fragment_shaders[i].shader
            end
        end
    end
end

---add functions to env table
---@param game table
function M.use(game)
    local pack = game.pack_data
    local lua_runtime = require("compat.game21.lua_runtime")
    local env = lua_runtime.env
    shaders = {}
    loaded_filenames = {}
    uniform_values = {}
    env.shdr_getShaderId = function(filename)
        if args.headless then
            return -1
        end
        return get_shader_id(pack, filename)
    end
    env.shdr_getDependencyShaderId = function(disambiguator, name, author, filename)
        if args.headless then
            return -1
        end
        local pack_id = disambiguator .. "_" .. author .. "_" .. name
        pack_id = pack_id:gsub(" ", "_")
        return get_shader_id(pack.dependencies[pack_id] or pack, filename)
    end

    -- making sure we don't need to create new tables all the time
    local uniform_value = {}
    env.shdr_setUniformF = function(id, name, a)
        set_uniform(id, "float", name, a or 0)
    end
    env.shdr_setUniformFVec2 = function(id, name, a, b)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        set_uniform(id, "vec2", name, uniform_value)
    end
    env.shdr_setUniformFVec3 = function(id, name, a, b, c)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        set_uniform(id, "vec3", name, uniform_value)
    end
    env.shdr_setUniformFVec4 = function(id, name, a, b, c, d)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        uniform_value[4] = d or 0
        set_uniform(id, "vec4", name, uniform_value)
    end
    env.shdr_setUniformI = function(id, name, a)
        set_uniform(id, "int", name, a or 0)
    end
    env.shdr_setUniformIVec2 = function(id, name, a, b)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        set_uniform(id, "ivec2", name, uniform_value)
    end
    env.shdr_setUniformIVec3 = function(id, name, a, b, c)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        set_uniform(id, "ivec3", name, uniform_value)
    end
    env.shdr_setUniformIVec4 = function(id, name, a, b, c, d)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        uniform_value[4] = d or 0
        set_uniform(id, "ivec4", name, uniform_value)
    end
    env.shdr_resetAllActiveFragmentShaders = function()
        for i = 0, 8 do
            status.fragment_shaders[i] = nil
        end
    end
    local function check_valid_render_stage(render_stage)
        if render_stage < 0 or render_stage > 8 then
            lua_runtime.error("Invalid render_stage '" .. render_stage .. "'")
            return false
        end
        return true
    end
    env.shdr_resetActiveFragmentShader = function(render_stage)
        render_stage = render_stage or 0
        if check_valid_render_stage(render_stage) then
            status.fragment_shaders[render_stage] = nil
        end
    end
    env.shdr_setActiveFragmentShader = function(render_stage, id)
        render_stage = render_stage or 0
        id = id or 0
        if check_valid_render_stage(render_stage) and check_valid_shader_id(id) then
            status.fragment_shaders[render_stage] = shaders[id]
        end
    end
end

return M
