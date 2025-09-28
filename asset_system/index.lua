local log = require("log")(...)
local json = require("extlibs.json.json")
local mirror_server = require("asset_system.mirror_server")
require("love.timer")

local index = {}

---@alias AssetId string internal asset id
---@alias MirrorKey string key used in mirrors
---@alias LoaderFunction fun(...: unknown): unknown
---@alias ResourceId string id for any type of non-asset resource a loader could depend on (e.g. a file)
---@alias Asset {
---  loader_function: LoaderFunction,
---  arguments: unknown[],
---  depended_on_by: table<AssetId, boolean>,
---  dependencies: AssetId[],
---  resources: table<ResourceId, boolean>,
---  id: AssetId,
---  key: MirrorKey?,
---  value: unknown?,
---  last_mirrored_value: unknown?,
---  last_mirror_targets: table<ThreadId, boolean>?,
---  mirror_targets: table<ThreadId, boolean>,
---}

-- this is the real global index
---@type table<AssetId, Asset>
local assets = {}
---@type table<MirrorKey, Asset>
local mirrored_assets = {}

-- allow unused assets to be retained for a certain amount of requests/reloads
-- this prevents them from unloading just before the next reload uses them again
local RETAIN_UNUSED_ASSETS = 2
---@type table<Asset, integer>
local unused_assets = {}

---goes through unused assets and unloads them if they have not been used too many times
local function process_unused_assets()
    for asset, unused_count in pairs(unused_assets) do
        if next(asset.depended_on_by) or asset.key then
            unused_assets[asset] = nil -- no longer unused
        else
            if unused_count >= RETAIN_UNUSED_ASSETS then
                index.unload(asset.id)
                unused_assets[asset] = nil
            else
                unused_assets[asset] = unused_count + 1
            end
        end
    end
end

-- used to get asset ids from resource id, as well as a resource's remove function
---@type table<ResourceId, { [1]: fun(resource: ResourceId)?, [AssetId]: boolean }>
local resource_watch_map = {}

-- used to check which asset is causing the loading of another asset to infer dependencies
---@type Asset[]
local loading_stack = {}
local loading_stack_index = 0

--#region printing statistics
local load_call_count = 0
local start_time

local function reset_stats()
    load_call_count = 0
    start_time = love.timer.getTime()
end

local function print_stats(start_text)
    if load_call_count > 0 then
        log(
            ("%s in %fs with %d loader call%s."):format(
                start_text,
                love.timer.getTime() - start_time,
                load_call_count,
                load_call_count > 1 and "s" or ""
            )
        )
    end
end
--#endregion

---puts an asset on the stack and calls its loader or unloads it
---@param asset Asset
---@param clear boolean?
---@param target_thread ThreadId?
local function load_asset(asset, clear, target_thread)
    -- push asset id to loading stack
    loading_stack_index = loading_stack_index + 1
    loading_stack[loading_stack_index] = asset

    -- back up and clear old data
    local resources = asset.resources
    asset.resources = {}
    local dependencies = asset.dependencies
    asset.dependencies = {}

    -- load the asset or set value to nil if clear is true
    asset.value = (not clear) and asset.loader_function(unpack(asset.arguments)) or nil
    load_call_count = load_call_count + 1

    -- resource removals (additions happen directly in index.watch)
    for resource_id in pairs(resources) do
        if not asset.resources[resource_id] then
            -- resource got removed
            local ids = resource_watch_map[resource_id]
            ids[asset.id] = nil
            -- call remove function if ids only has the element at 1 left
            if next(ids, next(ids)) == nil and ids[1] then
                ids[1](resource_id)
                resource_watch_map[resource_id] = nil
            end
        end
    end
    -- note dependency changes in other asset based on current and old dependency tables
    for i = 1, math.max(#dependencies, #asset.dependencies) do
        local old_dep = assets[dependencies[i]]
        local new_dep = assets[asset.dependencies[i]]
        if old_dep ~= new_dep then
            if old_dep then -- remove old dep
                old_dep.depended_on_by[asset.id] = nil
                -- schedule asset for unload if it is not mirrored and not depended on by any other assets
                if next(old_dep.depended_on_by) == nil and not old_dep.key then
                    unused_assets[old_dep] = 0
                end
            end
            if new_dep then -- add new dep
                new_dep.depended_on_by[asset.id] = true
            end
        end
    end

    -- pop asset id from loading stack
    loading_stack_index = loading_stack_index - 1

    -- only mirror after loading if there is a key
    if asset.key then
        mirror_server.schedule_sync(asset, target_thread)
    end
end

---get loader function based on loader string
---@param loader string
---@return LoaderFunction
---@nodiscard
local function get_loader_function(loader)
    local modname = loader:match("(.*)%.")
    local module = modname and require("asset_system.loaders." .. modname) or require("asset_system.loaders")
    local funname = loader:match(".*%.(.*)") or loader
    local loader_function = module[funname]
    if not loader_function then
        error(("Could not find loader '%s'"):format(loader))
    end
    return loader_function
end

---generates a unique asset id based on the loader and the parameters
---@param loader string
---@param ... unknown
---@return AssetId
---@nodiscard
local function generate_asset_id(loader, ...)
    local args = { ... }
    local info = debug.getinfo(get_loader_function(loader))
    local limit = info.isvararg and #args or math.min(info.nparams, #args)
    for i = 1, limit do
        args[i] = type(args[i]) == "table" and json.encode(args[i]) or tostring(args[i])
    end
    return ("%s(%s)"):format(loader, table.concat(args, ",", 1, limit))
end

---request an asset to be loaded and mirrored into the index
---(mirroring only happens for this asset if a key is given)
---@param key MirrorKey?
---@param loader string
---@param ... unknown
function index.request(key, loader, ...)
    if loading_stack_index == 0 then
        reset_stats()
    end

    -- put asset in index if not already there
    local id = generate_asset_id(loader, ...)
    assets[id] = assets[id]
        or {
            loader_function = get_loader_function(loader),
            arguments = { ... },
            depended_on_by = {},
            dependencies = {},
            resources = {},
            id = id,
            mirror_targets = {},
        }
    local asset = assets[id]

    -- if a key is given set the asset to use it and make sure it doesn't already have another one
    if key then
        if asset.key then
            assert(asset.key == key, "requested the same asset with a different key")
        else
            asset.key = key
            mirrored_assets[key] = asset
        end
    end

    -- schedule sync if thread is requesting asset for the first time
    local calling_thread = index._threadify_calling_thread_id
    if key and not asset.mirror_targets[calling_thread] then
        asset.mirror_targets[calling_thread] = true
        mirror_server.schedule_sync(asset, calling_thread)
    end

    -- if asset is requested from another loader the other one has this one as dependency
    if loading_stack_index > 0 then
        local caller = loading_stack[loading_stack_index]
        caller.dependencies[#caller.dependencies + 1] = id
    end

    -- only load if the asset is not already loaded
    if not asset.value then
        load_asset(asset, false, calling_thread)
    end

    -- mirror all pending assets once at the end of the initial request
    if loading_stack_index == 0 then
        mirror_server.sync_pending_assets()
        print_stats("Processed request for '" .. asset.key .. "'")
        process_unused_assets()
    end
end

---same as request but returns the asset's value (for use in loaders)
---also leaves the key as nil, since it's only used in this thread
---@param loader string
---@param ... unknown
---@return unknown
---@nodiscard
function index.local_request(loader, ...)
    index.request(nil, loader, ...)
    return assets[generate_asset_id(loader, ...)].value
end

---unload an asset
---@param id_or_key AssetId|MirrorKey
function index.unload(id_or_key)
    local asset = mirrored_assets[id_or_key] or assets[id_or_key]
    if next(asset.depended_on_by) ~= nil then
        local t = {}
        for id in pairs(asset.depended_on_by) do
            t[#t + 1] = id
        end
        error(("can't unload asset %s, it is still depended on by %s"):format(id_or_key, table.concat(t, ", ")))
    end

    -- clear asset value and update other assets
    load_asset(asset, true)

    -- remove from index
    assets[asset.id] = nil

    -- only mirror after unloading if there is a key
    if asset.key then
        mirrored_assets[asset.key] = nil
        mirror_server.sync_pending_assets()
        asset.mirror_targets = {}
    end
end

---traverses the asset dependency tree without duplicates
---returns a sequence of asset ids in the correct order
---@param asset_ids table<AssetId, boolean>
---@return AssetId[]
---@nodiscard
local function reload_traverse(asset_ids)
    local plan = {}
    repeat
        local next_assets = {}
        for dependee in pairs(asset_ids) do
            if type(dependee) == "string" then -- ignore other table content
                for new_dependee in pairs(assets[dependee].depended_on_by) do
                    next_assets[new_dependee] = true
                end
                for i = #plan, 1, -1 do
                    if plan[i] == dependee then
                        table.remove(plan, i)
                    end
                end
                plan[#plan + 1] = dependee
            end
        end
        asset_ids = next_assets
    until not next(asset_ids)
    return plan
end

---reloads an asset, using either its id or key
---@param id_or_key AssetId|MirrorKey
function index.reload(id_or_key)
    reset_stats()
    local asset = mirrored_assets[id_or_key] or assets[id_or_key]
    load_asset(asset)

    -- reload asset and ones that depend on it
    local plan = reload_traverse({ [asset] = true })
    for i = 1, #plan do
        load_asset(assets[plan[i]])
    end

    -- mirror all pending assets once at the end of the initial reload
    mirror_server.sync_pending_assets()
    print_stats("Reloaded '" .. id_or_key .. "'")
end

--#region resource handling

---watch any external resource, the id has to be unique
---@param resource_id ResourceId
---@param watch_add fun(resource: ResourceId)?
---@param watch_del fun(resource: ResourceId)?
function index.watch(resource_id, watch_add, watch_del)
    assert(loading_stack_index > 0, "cannot register resource watcher outside of asset loader")
    local asset = loading_stack[loading_stack_index]
    assets[asset.id].resources[resource_id] = true
    if resource_watch_map[resource_id] then
        local ids = resource_watch_map[resource_id]
        ids[asset.id] = true
        return false
    end
    resource_watch_map[resource_id] = { watch_del, [asset.id] = true }
    if watch_add then
        watch_add(resource_id)
    end
end

---notify asset index of changes in an external resource
---@param ... ResourceId
function index.changed(...)
    reset_stats()
    -- get assets that depend on the resources
    local asset_set = {}
    for i = 1, select("#", ...) do
        local resource_id = select(i, ...)
        if resource_watch_map[resource_id] then
            for asset in pairs(resource_watch_map[resource_id]) do
                asset_set[asset] = true
            end
        end
    end
    -- reload assets that depend on the resources
    local plan = reload_traverse(asset_set)
    for j = 1, #plan do
        load_asset(assets[plan[j]])
    end
    -- process changed assets
    mirror_server.sync_pending_assets()
    print_stats("Processed resource changes")
    process_unused_assets()
end

local threadify = require("threadify")
local watcher = threadify.require("asset_system.file_monitor", true)

---adds the specified file as dependency for the currently loading asset
---@param path string
function index.watch_file(path)
    index.watch(path, watcher.add, watcher.remove)
end

--#endregion

return index
