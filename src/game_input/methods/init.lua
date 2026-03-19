-- Input methods used only the game.
-- The ui has it's own hardcoded bindings
-- ? Whether default ui bindings will become editable is unknown.
-- ? Though other than a hotkey/keyboard shortcut system, probably not. 

return {
    keyboard = require("game_input.methods.keyboard"),
    mouse = require("game_input.methods.mouse"),
    touch = require("game_input.methods.touch"),
}
