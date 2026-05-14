hl.window_rule({
    name = "suppress_event maximize",
    match = {
        class = ".*"
    }
})

hl.window_rule({
    name = "no focus on",
    match = {
        class = "^$",
        title = "^$",
        xwayland = 1,
        float = 1,
        fullscreen = 0,
        pin = 0
    }
})

-- Make mpv float
hl.window_rule({
    name = "float mpv",
    match = {
        title = "mpv"
    },
    float = true,
    pin = true,
    size = {480, 270},
    move = {"monitor_w - 490", "monitor_h - 280"},
    opacity = 1.6
})

-- Make PIP float
hl.window_rule({
    name = "float PIP",
    match = {
        title = "Picture in picture"
    },
    float = true,
    pin = true,
    move = {"monitor_w * 1 - window_w - 10", "monitor_h * 1 - window_h - 10"},
    opacity = 1.6
})

-- Float XDG Desktop Portal
hl.window_rule({
    name = "float XDG Desktop Portal",
    match = {
        class = "^(xdg-desktop-portal|org.freedesktop.impl.portal.*)$"
    },
    float = true,
    center = true
})

-- Also float and center other common file picker dialogs
hl.window_rule({
    name = "float file pickers",
    match = {
        title = "^(Open File|Save File|File Upload|Open Files|Save File|Save Files)$"
    },
    float = true,
    center = true,
    opacity = 1.6
})
