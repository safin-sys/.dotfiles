local env = require("envs")
local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(env.terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(env.file_manager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(env.browser))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(env.menu))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(env.audio))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(env.power))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(env.wallpaper))

-- System
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({
    action = "toggle"
}))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.window.set_prop({
    prop = "opaque",
    value = "toggle",
    window = "activewindow"
}))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("bash -c 'killall -q waybar; sleep 0.5; waybar & disown'"))
hl.bind(mainMod .. " + D", hl.dsp.window.pseudo())

-- Move focus
hl.bind(mainMod .. " + left", hl.dsp.focus({
    direction = "left"
}))
hl.bind(mainMod .. " + right", hl.dsp.focus({
    direction = "right"
}))
hl.bind(mainMod .. " + up", hl.dsp.focus({
    direction = "up"
}))
hl.bind(mainMod .. " + down", hl.dsp.focus({
    direction = "down"
}))

-- Move windows
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({
    direction = "left"
}))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({
    direction = "right"
}))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({
    direction = "up"
}))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({
    direction = "down"
}))

-- Swap windows
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.swap({
    direction = "left"
}))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({
    direction = "right"
}))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.swap({
    direction = "up"
}))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.swap({
    direction = "down"
}))

-- Resize windows
-- hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({-50, 0}))
-- hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({50, 0}))
-- hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({0, -50}))
-- hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({0, 50}))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({
        workspace = i
    }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({
        workspace = i
    }))
end

hl.bind(mainMod .. " + tab", hl.dsp.focus({
    workspace = "m+1"
}))
hl.bind(mainMod .. " + SHIFT + tab", hl.dsp.focus({
    workspace = "m-1"
}))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({
    workspace = "e+1"
}))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({
    workspace = "e-1"
}))

-- Fullscreen
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({
    mode = "maximized"
}))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen())

-- Toggle focus (alt+tab)
hl.bind("ALT + tab", hl.dsp.window.cycle_next())

-- Mouse drag/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), {
    mouse = true
})
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), {
    mouse = true
})

-- Volume / brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), {
    locked = true,
    repeating = true
})

-- Media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), {
    locked = true
})
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true
})
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true
})
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), {
    locked = true
})

-- Screenshot
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast --freeze --notify copy area"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("grimblast --freeze --notify copy screen"))
