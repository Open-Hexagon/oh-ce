return function(width, height)
    return math.max(0.5, math.floor(10 / math.max(1920 / width, 1080 / height)) / 10)
end
