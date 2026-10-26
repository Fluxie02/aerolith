-- AEROLITH / Limb. Optional appearance fragment for Hyprland 0.55+.
-- Load with dofile("/absolute/path/to/themes/hyprland/aerolith.lua").
-- No bindings, processes, monitor policy, layout or animation changes.
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border = "rgb(ceebac)",
            inactive_border = "rgb(3b5253)",
        },
    },
    decoration = {
        rounding = 20,
        rounding_power = 2.0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = { enabled = false },
        shadow = { enabled = false },
    },
})
