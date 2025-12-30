if status is-interactive
end

set -gx TERM xterm-256color

starship init fish | source

if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
    exec start-hyprland >/dev/null 2>&1
end

# pnpm
set -gx PNPM_HOME "/home/elliot/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
