local logging = require("logging")
local log = logging.get_logger(...)

local utf8 = require("utf8")

local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1)):gsub("\n[^\n]+$", "")))
end

-- slightly modified error handler from the love2d wiki that logs the error

function love.errorhandler(msg)
    msg = tostring(msg)

    error_printer(msg, 2)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then
            return
        end
    end

    -- Reset state.
    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
        if love.mouse.isCursorSupported() then
            love.mouse.setCursor()
        end
    end
    if love.joystick then
        -- Stop all joystick vibrations.
        for i, v in ipairs(love.joystick.getJoysticks()) do
            v:setVibration()
        end
    end
    if love.audio then
        love.audio.stop()
    end

    love.graphics.reset()

    love.graphics.setFont(love.graphics.newFont(14))

    love.graphics.setColor(1, 1, 1)

    local trace = debug.traceback()

    love.graphics.origin()

    ---@type table|string
    local sanitizedmsg = {}
    for char in msg:gmatch(utf8.charpattern) do
        table.insert(sanitizedmsg --[[@as table]], char)
    end
    sanitizedmsg = table.concat(sanitizedmsg --[[@as table]])

    local err = {}

    table.insert(err, "Error: ")
    table.insert(err, sanitizedmsg)

    if #sanitizedmsg ~= #msg then
        table.insert(err, "Invalid UTF-8 string in error message.")
    end

    table.insert(err, "\n\n")
    table.insert(err, trace)
    table.insert(err, "\n")

    local p = table.concat(err)
    log:error("The game has crashed!\n\n" .. p)

    local function draw()
        if not love.graphics.isActive() then
            return
        end
        local pos = 70
        love.graphics.clear(0.15, 0.15, 0.15)
        love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
        love.graphics.present()
    end

    local fullErrorText = p
    local function copyToClipboard()
        if not love.system then
            return
        end
        love.system.setClipboardText(fullErrorText)
        p = p .. "\nCopied to clipboard!"
    end

    if love.system then
        p = p .. "\n\nPress Ctrl+C or tap to copy this error"
    end

    return function()
        love.event.pump()

        for e, a, b, c in love.event.poll() do
            if e == "quit" then
                goto quit
            elseif e == "keypressed" and a == "escape" then
                goto quit
            elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
                copyToClipboard()
            elseif e == "touchpressed" then
                local name = love.window.getTitle()
                if #name == 0 or name == "Untitled" then
                    name = "Game"
                end
                local buttons = { "OK", "Cancel" }
                if love.system then
                    buttons[3] = "Copy to clipboard"
                end
                local pressed = love.window.showMessageBox("Quit " .. name .. "?", "", buttons)
                if pressed == 1 then
                    goto quit
                elseif pressed == 3 then
                    copyToClipboard()
                end
            end
        end

        draw()

        if love.timer then
            love.timer.sleep(0.1)
        end

        do
            return
        end

        ::quit::
        logging.flush_all()
        logging.close_all()
        return 1
    end
end
