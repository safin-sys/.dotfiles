local home = os.getenv("HOME")

-- Nvidia
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

return {
    -- Programs
    terminal = "kitty",
    file_manager = "nautilus",
    menu = "pkill rofi || true && rofi -show drun -show-icons -theme ~/.config/rofi/app.rasi",
    browser = "google-chrome-stable",

    -- Scripts
    wallpaper = home .. "/.config/hypr/scripts/set-wallpaper.sh",
    toggle_opacity = home .. "/.config/hypr/scripts/toggle-opacity.sh",
    audio = home .. "/.config/hypr/scripts/audio.sh",
    power = home .. "/.config/hypr/scripts/power.sh"
}
