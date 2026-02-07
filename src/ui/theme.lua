local theme = {}

theme.themes = {
    old_default = {
        text_color = { 1, 1, 1, 1 },
        greyed_out_text_color = { 1, 1, 1, 0.5 },
        highlight_text_color = { 0.5, 0.5, 0, 1 },
        contrast_text_color = { 0, 0, 0, 1 },
        background_color = { 0, 0, 0, 1 },
        contrast_background_color = { 1, 1, 1, 1 },
        light_background_color = { 0.5, 0.5, 0.5, 1 },
        selection_color = { 0, 0, 1, 1 },
        light_selection_color = { 0.5, 0.5, 1, 1 },
        transparent_light_selection_color = { 0.5, 0.5, 0, 1 },
        border_color = { 1, 1, 1, 1 },
        border_thickness = 1,
        selection_border_thickness = 2,
    },
    default = {
        text_color = { 1, 1, 1, 1 },
        greyed_out_text_color = { 1, 1, 1, 0.5 },
        highlight_text_color = { 0.5, 0.5, 0, 1 },
        contrast_text_color = { 0, 0, 0, 1 },
        background_color = { 0.1, 0.1, 0.1, 0.7 },
        contrast_background_color = { 1, 1, 1, 1 },
        light_background_color = { 0.5, 0.5, 0.5, 1 },
        selection_color = { 0, 0, 1, 0.7 },
        light_selection_color = { 0.5, 0.5, 0, 1 },
        transparent_light_selection_color = { 0.5, 0.5, 0, 0.7 },
        border_color = { 0, 0, 0, 0.7 },
        border_thickness = 2,
        selection_border_thickness = 4,
    },
}

theme.current_theme = theme.themes.default

function theme.set(name)
    theme.current_theme = theme.themes[name]
end

function theme.get(key)
    return theme.current_theme[key] or theme.themes.default[key]
end

function theme.get_selection_handler()
    return function(self)
        if self.selected then
            self.border_color = theme.get("selection_color")
            self.border_thickness = theme.get("selection_border_thickness")
        else
            self.border_color = theme.get("border_color")
            self.border_thickness = theme.get("border_thickness")
        end
    end
end

return theme
