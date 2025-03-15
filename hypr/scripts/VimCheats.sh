#!/bin/bash
# /* ---- 💫 Vim Quick Cheat Sheet 💫 ---- */  ##

# GDK BACKEND. Change to either wayland or x11 if having issues
BACKEND=wayland

# Check if yad is running and kill it if it is
if pidof yad > /dev/null; then
  pkill yad
fi

# Launch yad with Vim commands cheat sheet
GDK_BACKEND=$BACKEND yad \
    --center \
    --title="Vim Quick Cheat Sheet" \
    --no-buttons \
    --list \
    --column=Key: \
    --column=Description: \
    --timeout-indicator=bottom \
"ESC" "Switch to normal mode" \
":w" "Save file" \
":q" "Quit Vim" \
":wq" "Save file and quit" \
":q!" "Force quit without saving" \
"i" "Insert mode" \
"a" "Append after cursor" \
"o" "Insert new line below cursor" \
"O" "Insert new line above cursor" \
"dd" "Delete current line" \
"yy" "Copy (yank) current line" \
"p" "Paste after cursor" \
"u" "Undo last change" \
"Ctrl + r" "Redo last undone change" \
"/pattern" "Search for 'pattern' in file" \
"n" "Move to next search result" \
"N" "Move to previous search result" \
":%s/old/new/g" "Replace all occurrences of 'old' with 'new'" \
":set number" "Show line numbers" \
":set nonumber" "Hide line numbers" \
"gg" "Go to top of the file" \
"G" "Go to bottom of the file" \
"w" "Move forward by word" \
"b" "Move backward by word" \
"$" "Move to end of the line" \
"0" "Move to beginning of the line" \
"v" "Visual mode" \
"V" "Visual line mode" \
"Ctrl + v" "Visual block mode" \
":split" "Horizontal split window" \
":vsplit" "Vertical split window" \
"Ctrl + w, w" "Switch between windows" \
"Ctrl + w, q" "Close current window" \
"More Vim Tips:" "https://vim.rtorr.com/"
