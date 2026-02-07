-- TODO: implement functions and the game itself
local async = require("async")
local public = {
    running = false,
    first_play = true,
    tickrate = 240,
}

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
public.start = async(function(pack_id, level_id, level_options)
    public.running = true
end)

---update the game
function public.update()
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen)
end

---get the current score
---@return number
function public.get_score()
end

---get the timed current score even if there is a custom score
---@return number
function public.get_timed_score()
end

---returns true if the player has died
---@return boolean
function public.is_dead()
end

---stop the game
function public.stop()
    public.running = false
end

---initialize the game
---@param conf table
---@param audio table
public.init = async(function(conf, audio)
end)

---set the game's volume
---@param volume number
function public.set_volume(volume)
end

return public
