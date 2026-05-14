#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE="/tmp/wallpaper_cache"

pkill rofi 2>/dev/null

CURRENT_WP=$(awww query 2>/dev/null | sed -n 's/.*displaying: image:.*\/\(.*\)\.png/\1/p; s/.*displaying: image:.*\/\(.*\)\.jpg/\1/p')
[ -z "$CURRENT_WP" ] && CURRENT_WP="Wallpaper"

sed -i "s/placeholder:.*/placeholder:         \"$CURRENT_WP\";/" "$HOME/.config/rofi/wallpaper.rasi"

# Build cache if missing
if [ ! -f "$CACHE" ]; then
  find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) >"$CACHE"
fi

# Build rofi entries with icons
ROFI_INPUT="🎲 Random Wallpaper\0icon\x1fpreferences-desktop-wallpaper\n"

while IFS= read -r img; do
  name="$(basename "$img")"
  ROFI_INPUT+="${name}\0icon\x1f${img}\n"
done <"$CACHE"

SELECTED=$(echo -e "$ROFI_INPUT" | rofi -dmenu -theme wallpaper -p "$CURRENT_WP")

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
  awww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle "$ANGLE" \
    --transition-fps 165 \
    --transition-step 165
else
  awww img "$WALLPAPER" \
    --transition-type "$TRANSITION" \
    --transition-fps 165 \
    --transition-step 165
fi
