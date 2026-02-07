local particles = {}
particles.__index = particles

function particles:new(image, update_function, spawn_alpha, alpha_decay)
    return setmetatable({
        image = image,
        origin_offset = { image:getWidth() / 2, image:getHeight() / 2 },
        count = 0,
        spawn_alpha = spawn_alpha,
        alpha_decay = alpha_decay,
        update_function = update_function,
        _current_particle_index = 1,
    }, particles)
end

function particles:reset(count)
    -- update needs frametime (to determine amount of particles)
    -- so we do it later in the update function, unless a count is given
    self.count = count
    if count ~= nil then
        self:_real_reset()
    end
end

function particles:_real_reset()
    self.batch = love.graphics.newSpriteBatch(self.image, self.count, "stream")
    self.data = {}
    for i = 1, self.count do
        self.data[i] = {
            id = self.batch:add(0, 0, 0, 0, 0),
            color = { 0, 0, 0, 0 },
            x = 0,
            y = 0,
            scale = 0,
            angle = 0,
            speed_mult = 0,
        }
    end
end

function particles:set_image(image)
    self.image = image
    self.batch:setTexture(image)
end

function particles:emit(x, y, scale, angle, r, g, b, speed_mult)
    local data = self.data[self._current_particle_index]
    data.x = x
    data.y = y
    data.scale = scale
    data.angle = angle
    data.speed_mult = speed_mult
    data.color[1], data.color[2], data.color[3], data.color[4] = r / 255, g / 255, b / 255, self.spawn_alpha / 255
    self.batch:setColor(unpack(data.color))
    self.batch:set(data.id, data.x, data.y, data.angle, data.scale, data.scale, unpack(self.origin_offset))
    self._current_particle_index = self._current_particle_index % math.floor(self.count) + 1
end

function particles:update(frametime)
    if self.count == nil then
        self.count = (self.spawn_alpha + 3) / (self.alpha_decay * frametime) + 1
        self:_real_reset()
    end
    for i = 1, self.count do
        local data = self.data[i]
        if self.update_function(data, frametime) then
            data.scale = 0
        end
        self.batch:setColor(unpack(data.color))
        self.batch:set(data.id, data.x, data.y, data.angle, data.scale, data.scale, unpack(self.origin_offset))
    end
end

return particles
