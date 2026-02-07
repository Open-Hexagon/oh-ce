-- Some premade transitions
local transitions = {}

-- scale the element in the center
transitions.scale = {}

function transitions.scale.reset(layout)
    layout.transform.scaling.x:set_immediate_value(0)
    layout.transform.scaling.y:set_immediate_value(0)
    layout.transform.translation.x:set_immediate_value(layout.width / 2)
    layout.transform.translation.y:set_immediate_value(layout.height / 2)
end

function transitions.scale.open(layout)
    layout.transform:scale(1, 1)
    layout.transform:translate(0, 0)
end

function transitions.scale.close(layout)
    layout.transform:scale(0, 0)
    layout.transform:translate(layout.width / 2, layout.height / 2)
end

-- slide the element in
transitions.slide = {}

function transitions.slide.reset(layout)
    layout.transform.translation.x:set_immediate_value(-layout.last_available_width)
end

function transitions.slide.open(layout)
    layout.transform.translation.x:keyframe(0.1, 0)
end

function transitions.slide.close(layout)
    layout.transform:translate(-layout.last_available_width, 0)
end

return transitions
