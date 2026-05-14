hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = {
                colors = {"rgba(33ccffee)", "rgba(00ff99ee)"},
                angle = 45
            },
            inactive_border = "rgba(595959aa)"
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle"
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 0.9,
        inactive_opacity = 0.8,

        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)"
        },

        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            ignore_opacity = true,
            vibrancy = 0.1696
        }
    },

    master = {
        new_status = "master"
    },

    misc = {
        -- Set to 0 or 1 to disable the anime mascot wallpapers
        force_default_wallpaper = 1,
        -- If true disables the random hyprland logo / anime girl background. :(
        disable_hyprland_logo = true
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        -- -1.0 - 1.0, 0 means no modification.
        sensitivity = 0,

        touchpad = {
            natural_scroll = false
        }
    },

    -- device = {
    --     name = "epic-mouse-v1",
    --     sensitivity = -0.5
    -- },

    binds = {
        workspace_back_and_forth = true
    }
})

-- curves (replaces bezier = ...)
hl.curve("easeOutQuint", {
    type = "bezier",
    points = {{0.23, 1}, {0.32, 1}}
})
hl.curve("easeInOutCubic", {
    type = "bezier",
    points = {{0.65, 0.05}, {0.36, 1}}
})
hl.curve("linear", {
    type = "bezier",
    points = {{0, 0}, {1, 1}}
})
hl.curve("almostLinear", {
    type = "bezier",
    points = {{0.5, 0.5}, {0.75, 1.0}}
})
hl.curve("quick", {
    type = "bezier",
    points = {{0.15, 0}, {0.1, 1}}
})

-- animations (replaces animation = ...)
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 10,
    bezier = "default"
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 5.39,
    bezier = "easeOutQuint"
})
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4.79,
    bezier = "easeOutQuint"
})
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 4.1,
    bezier = "easeOutQuint",
    style = "popin 60%"
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.49,
    bezier = "linear",
    style = "popin 60%"
})
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 1.73,
    bezier = "almostLinear"
})
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 1.46,
    bezier = "almostLinear"
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 3.03,
    bezier = "quick"
})
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 3.81,
    bezier = "easeOutQuint"
})
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 4,
    bezier = "easeOutQuint",
    style = "fade"
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 1.5,
    bezier = "linear",
    style = "fade"
})
hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 1.79,
    bezier = "almostLinear"
})
hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 1.39,
    bezier = "almostLinear"
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 1.94,
    bezier = "almostLinear",
    style = "fade"
})
hl.animation({
    leaf = "workspacesIn",
    enabled = true,
    speed = 3,
    bezier = "almostLinear",
    style = "slidefade"
})
hl.animation({
    leaf = "workspacesOut",
    enabled = true,
    speed = 3,
    bezier = "almostLinear",
    style = "slidefade"
})
