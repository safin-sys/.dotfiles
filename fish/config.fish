if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -gx TERM xterm-256color

starship init fish | source
