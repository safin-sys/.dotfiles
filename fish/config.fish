if status is-interactive
end

set -gx TERM xterm-256color

starship init fish | source

if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
    exec Hyprland >/dev/null 2>&1
end
