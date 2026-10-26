-- AEROLITH THEARS / app rules, Hyprland 0.55+ Lua syntax.
-- Include this OR thears.conf, and only one direction. Optional, never installed here.
-- No focus/activation rules; no game-class, fullscreen or maximize decoration rules.
-- Check actual app identities with hyprctl clients before adopting.
-- PhotoCraft app ID: upstream apps/photocraft/src/main.rs APP_ID.
local apps = {
    { "photocraft", [=[^ai\.storyteller\.photocraft$]=] },
    { "firefox", [=[^(firefox|firefox-esr|org\.mozilla\.(firefox|Firefox))$]=] },
    { "libreoffice", [=[^(libreoffice(-writer|-calc|-impress|-draw|-base|-math|-startcenter)?|org\.libreoffice\.LibreOffice)$]=] },
    { "steam", [=[^(steam|Steam)$]=] },
    { "discord", [=[^(discord|Discord|discordcanary|discordptb|vesktop|Vesktop|com\.discordapp\.Discord|dev\.vencord\.Vesktop)$]=] },
}
for _, app in ipairs(apps) do
    hl.window_rule({
        match = { class = app[2], fullscreen = false },
        rounding = 20,
        border_size = 2,
        border_color = "rgb(ffc08a) rgb(685144)",
        no_blur = true,
        no_shadow = true,
    })
    hl.window_rule({
        match = { class = app[2], modal = true, fullscreen = false },
        float = true,
        center = true,
    })
end

-- Narrow English-title auxiliaries; omit or adapt titles for another locale.
hl.window_rule({
    match = { class = "^(steam|Steam)$", title = "^(Friends List|Steam Settings)$", fullscreen = false },
    float = true,
    center = true,
})
hl.window_rule({
    match = { class = "^(discord|Discord|vesktop|Vesktop)$", title = "^Discord Popout$", fullscreen = false },
    float = true,
    center = true,
})
hl.window_rule({
    match = { class = [=[^(firefox|firefox-esr|org\.mozilla\.(firefox|Firefox))$]=], title = "^Picture-in-Picture$", fullscreen = false },
    float = true,
})
