local module_map = {
    threadify = "update",
    ["asset_system.mirror_client"] = "update",
}

return function()
    local fns = {}
    for modname in pairs(package.loaded) do
        local fun_name = module_map[modname]
        if fun_name then
            local index = #fns + 1
            fns[index] = setmetatable({}, {
                __call = function()
                    -- try resolving require, may fail a few times when modules are partially loaded
                    local success, module = pcall(require, modname)
                    if success then
                        fns[index] = module[fun_name]
                        fns[index]()
                    end
                end,
            })
        end
    end
    return function()
        for i = 1, #fns do
            fns[i]()
        end
    end, #fns
end
