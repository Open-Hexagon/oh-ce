-- this is required everywhere, so it's its own module
return function(r, g, b, a)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
end
