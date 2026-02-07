local assets = require("asset_system")
local threadify = require("threadify")
local download
if love.system.getOS() ~= "Web" then
    download = threadify.require("ui.overlay.packs.download_thread")
end

local preview = {}
preview.__index = preview

function preview:new()
    return setmetatable({
        rotation = 0,
    }, preview)
end

function preview:get_data()
    self.data = (assets.mirror[self.key] or {})[self.level] or self.data
end

function preview:set(game_version, pack, level, has_pack)
    if has_pack == nil then
        has_pack = true
    end
    self.level = level
    self.key = "preview_data_" .. game_version .. "_" .. pack
    if has_pack then
        assets.index.request(self.key, "pack.compat.preview_data", game_version, pack):done(function()
            self:get_data()
        end)
    else
        download.get_preview_data(game_version, pack):done(function(data)
            self.data = data[level]
        end)
    end
end

function preview:draw(fullscreen)
    self:get_data()
    if not self.data then
        return
    end
    if self.data ~= self.last_data then
        self.last_data = self.data
        self.vertices = {}
    end
    if fullscreen then
        local w, h = love.graphics.getDimensions()
        love.graphics.push()
        love.graphics.translate(w / 2, h / 2)
        local zoom_factor = 1 / math.max(1024 / w, 768 / h)
        love.graphics.scale(zoom_factor, zoom_factor)
        love.graphics.rotate(self.rotation)
        self.rotation = self.rotation - self.data.rotation_speed * love.timer.getDelta()
    end
    self.vertices = self.vertices or {}
    local distance = fullscreen and 10000 or 48
    local pivot_thickness = fullscreen and 5 or 2
    for i = 1, self.data.sides do
        local angle1 = i * 2 * math.pi / self.data.sides - math.pi / 2
        local cos1 = math.cos(angle1)
        local sin1 = math.sin(angle1)
        local angle2 = angle1 + 2 * math.pi / self.data.sides
        local cos2 = math.cos(angle2)
        local sin2 = math.sin(angle2)
        -- background
        love.graphics.setColor(self.data.background_colors[i])
        love.graphics.polygon("fill", 0, 0, cos1 * distance, sin1 * distance, cos2 * distance, sin2 * distance)
        self.vertices[(i - 1) * 2 + 1] = cos1 * distance
        self.vertices[i * 2] = sin1 * distance
    end
    local cap_mult = fullscreen and 0.0075 or 1 / 3
    -- pivot
    love.graphics.setColor(self.data.pivot_color)
    local pivot_mult = cap_mult + pivot_thickness / 2 / distance
    love.graphics.scale(pivot_mult, pivot_mult)
    love.graphics.setLineWidth(pivot_thickness / pivot_mult)
    love.graphics.polygon("line", self.vertices)
    love.graphics.scale(1 / pivot_mult, 1 / pivot_mult)
    -- cap
    love.graphics.scale(cap_mult, cap_mult)
    love.graphics.setColor(self.data.cap_color)
    love.graphics.polygon("fill", self.vertices)
    love.graphics.scale(1 / cap_mult, 1 / cap_mult)
    if fullscreen then
        love.graphics.pop()
    end
end

return preview
