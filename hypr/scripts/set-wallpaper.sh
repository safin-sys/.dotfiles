#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE="/tmp/wallpaper_cache"

pkill rofi 2>/dev/null

# Build cache if missing
if [ ! -f "$CACHE" ]; then
  find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) > "$CACHE"
fi

# Build rofi entries with icons
ROFI_INPUT="🎲 Random Wallpaper\0icon\x1fpreferences-desktop-wallpaper\n"

while IFS= read -r img; do
  name="$(basename "$img")"
  ROFI_INPUT+="${name}\0icon\x1f${img}\n"
done < "$CACHE"

# Rofi grid theme (inline)
THEME='
configuration {
  show-icons: true;
}

listview {
  columns: 5;
  lines: 3;
  fixed-height: true;
}

element {
  orientation: vertical;
  padding: 8px;
}

element-icon {
  size: 100px;
}

element-text {
  horizontal-align: 0.5;
  vertical-align: 0.5;
}
'

SELECTED=$(echo -e "$ROFI_INPUT" | rofi -dmenu -theme-str "$THEME" -p "Wallpaper")

[ -z "$SELECTED" ] && exit 0

if [ "$SELECTED" = "🎲 Random Wallpaper" ]; then
  WALLPAPER=$(shuf -n 1 "$CACHE")
else
  WALLPAPER=$(grep "/$SELECTED$" "$CACHE")
fi

[ -z "$WALLPAPER" ] && exit 1

# Random transition
TRANSITION=$(shuf -n 1 -e wipe outer center)

if [ "$TRANSITION" = "wipe" ]; then
  ANGLE=$((RANDOM % 360))
  swww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle "$ANGLE" \
    --transition-fps 165 \
    --transition-step 165
else
  swww img "$WALLPAPER" \
    --transition-type "$TRANSITION" \
    --transition-fps 165 \
    --transition-step 165
fi
