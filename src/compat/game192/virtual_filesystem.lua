local log = require("log")
local utils = require("compat.game192.utils")
local tmpfile = require("compat.game192.tmpfile")
local vfs = {
    pack_path = "",
    pack_folder_name = "",
}

local virtual_filesystem = {}

---fake io module for modifying the virtual filesystem
vfs.io = setmetatable({}, {
    __index = function(_, k)
        return function(f, ...)
            if f ~= nil and f[k] ~= nil then
                return f[k](f, ...)
            end
            if type(f) == "table" then
                return io[k](f.file, ...)
            else
                return io[k](f, ...)
            end
        end
    end,
})

local fake_file = {
    __index = function(t, k)
        if type(t.file[k]) == "function" then
            return function(self, ...)
                if type(self) == "table" then
                    return t.file[k](self.file, ...)
                else
                    return t.file[k](self, ...)
                end
            end
        else
            return t.file[k]
        end
    end,
}

---remove all files in the virtual filesystem
vfs.clear = function()
    for path, file in pairs(virtual_filesystem) do
        file.file:close()
        virtual_filesystem[path] = nil
    end
    tmpfile.clear()
end

---remove a file
---@param path string
vfs.remove = function(path)
    if virtual_filesystem[path] ~= nil then
        virtual_filesystem[path].file:close()
        virtual_filesystem[path] = nil
    end
end

---return a table with the contents of all files
---@return table
vfs.dump_files = function()
    local files = {}
    for path, file in pairs(virtual_filesystem) do
        file:seek("set", 0)
        files[path] = file:read("*a")
        file:close()
    end
    return files
end

vfs.dump_real_files_recurse = function()
    local files = {}
    for path, file in pairs(virtual_filesystem) do
        -- not dumping file outside Packs folder (irrelevant for asset loading)
        if path:sub(1, 5) == "Packs" then
            path = path:gsub("\\", "/"):gsub("%.%./", ""):sub(7)
            local keys = {}
            for segment in path:gmatch("([^/]+)") do
                keys[#keys + 1] = segment
            end
            file:seek("set", 0)
            utils.insert_path(files, keys, file:read("*a"))
            file:close()
        end
    end
    return files
end

local function new_file()
    return setmetatable({
        file = tmpfile.create(),
        close = function(self)
            self.file:seek("set", 0)
            return true
        end,
    }, fake_file)
end

---load a table of file contents into the virtual filesystem
---@param files table
vfs.load_files = function(files)
    for path, contents in pairs(files) do
        local file = new_file()
        file:write(contents)
        file:seek("set", 0)
        virtual_filesystem[path] = file
    end
end

vfs.io.open = function(path, mode)
    mode = mode or "r"
    mode = mode:sub(0, 1)
    if mode == "w" or mode == "a" then
        if mode == "a" and virtual_filesystem[path] ~= nil then
            virtual_filesystem[path]:seek("end", 0)
            return virtual_filesystem[path]
        end
        local file = new_file()
        virtual_filesystem[path] = file
        return file
    elseif mode == "r" then
        if virtual_filesystem[path] == nil then
            if path:sub(1, 5) == "Packs" then
                local new_path = vfs.pack_path .. path:sub(8 + #vfs.pack_folder_name)
                new_path = new_path:gsub("\\", "/"):gsub("%.%./", "")
                local file, error_msg = love.filesystem.openFile(new_path, "r")
                if error_msg then
                    log("Error loading file '" .. new_path .. "': " .. error_msg)
                    return
                end
                local contents = file:read()
                file:close()
                file = new_file()
                file:write(contents)
                file:close()
                virtual_filesystem[path] = file
                return file
            else
                log("attempted to access file outside of pack folder: '" .. path .. "'")
                return
            end
        else
            virtual_filesystem[path]:seek("set", 0)
            return virtual_filesystem[path]
        end
    else
        error("Unsupported file mode: " .. mode)
    end
end

vfs.io.lines = function(filename)
    if filename == nil then
        -- TODO
    else
        local file = vfs.io.open(filename)
        if file then
            return file:lines()
        else
            error("cannot open '" .. filename .. "' no such file or directory")
        end
    end
end

return vfs
