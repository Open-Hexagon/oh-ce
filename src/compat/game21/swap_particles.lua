local Particles = require("compat.game21.particles")
local player = require("compat.game21.player")
local assets = require("asset_system")
local async = require("async")
local swap_particles = {}
local spawn_swap_particles_ready = false
local must_spawn_swap_particles = false
local swap_particle_info = { x = 0, y = 0, angle = 0 }
local particle_system

function swap_particles.init()
    if not particle_system then
        async.await(assets.index.request("small_circle_image", "image", "assets/image/smallCircle.png"))
        particle_system = Particles:new(assets.mirror.small_circle_image, function(p, frametime)
            p.color[4] = p.color[4] - 3.5 / 255 * frametime
            p.scale = p.scale * 0.98
            p.x = p.x + math.cos(p.angle) * p.speed_mult * frametime
            p.y = p.y + math.sin(p.angle) * p.speed_mult * frametime
            return p.color[4] <= 3 / 255
        end)
    end
    particle_system:reset(30)
end

function swap_particles.ready()
    must_spawn_swap_particles = true
    spawn_swap_particles_ready = true
    swap_particle_info.x, swap_particle_info.y = player.get_position()
    swap_particle_info.angle = player.get_player_angle()
end

function swap_particles.swap()
    must_spawn_swap_particles = true
    spawn_swap_particles_ready = false
    swap_particle_info.x, swap_particle_info.y = player.get_position()
    swap_particle_info.angle = player.get_player_angle()
end

function swap_particles.update(frametime, current_trail_color)
    particle_system:update(frametime)
    if must_spawn_swap_particles then
        must_spawn_swap_particles = false
        local function spawn_particle(expand, speed_mult, scale_mult, alpha)
            particle_system.spawn_alpha = alpha
            particle_system:emit(
                swap_particle_info.x,
                swap_particle_info.y,
                (love.math.random() * 0.7 + 0.65) * scale_mult,
                swap_particle_info.angle + (love.math.random() * 2 - 1) * expand,
                current_trail_color[1],
                current_trail_color[2],
                current_trail_color[3],
                (love.math.random() * 9.9 + 0.1) * speed_mult
            )
        end
        if spawn_swap_particles_ready then
            for _ = 1, 14 do
                spawn_particle(3.14, 1.3, 0.4, 140)
            end
        else
            for _ = 1, 20 do
                spawn_particle(0.45, 1, 1, 45)
            end
            for _ = 1, 10 do
                spawn_particle(3.14, 0.45, 0.75, 35)
            end
        end
    end
end

function swap_particles.draw()
    love.graphics.draw(particle_system.batch)
end

return swap_particles
