#!/bin/bash

# Set your wallpaper directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Kill any existing wofi processes to prevent multiple windows
pkill wofi

# Get current wallpaper (remove path and extension for display)
CURRENT_WALLPAPER=$(swww query | grep -o 'image: .*' | cut -d' ' -f2- | sed 's|.*/||' | sed 's/\.[^.]*$//')
if [ -z "$CURRENT_WALLPAPER" ]; then
    CURRENT_WALLPAPER="None"
fi

# Cache wallpaper list for better performance
WALLPAPER_CACHE_FILE="/tmp/wallpaper_list_$(basename "$WALLPAPER_DIR")"
WALLPAPER_CACHE_AGE=300  # 5 minutes

# Check if cache is fresh
if [ ! -f "$WALLPAPER_CACHE_FILE" ] || [ $(($(date +%s) - $(stat -c %Y "$WALLPAPER_CACHE_FILE" 2>/dev/null || echo 0))) -gt $WALLPAPER_CACHE_AGE ]; then
    # Generate fresh cache
    find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.png' \) > "$WALLPAPER_CACHE_FILE"
fi

# Get list of wallpapers from cache and format them for display (filename only, no extension)
WALLPAPERS=$(cat "$WALLPAPER_CACHE_FILE" | xargs -n1 basename | sed 's/\.[^.]*$//')

# Add random option at the beginning
OPTIONS="🎲 Random Wallpaper\n$WALLPAPERS"

# Use wofi to pick an option with current wallpaper shown in prompt
SELECTED=$(echo -e "$OPTIONS" | wofi --dmenu --prompt "$CURRENT_WALLPAPER")

# If selection is not empty, set it with swww
if [ -n "$SELECTED" ]; then
  if [ "$SELECTED" = "🎲 Random Wallpaper" ]; then
    # Select a random wallpaper using cached list for better performance
    if [ -s "$WALLPAPER_CACHE_FILE" ]; then
      # Count lines and get random line number
      TOTAL_WALLPAPERS=$(wc -l < "$WALLPAPER_CACHE_FILE")
      RANDOM_LINE=$(od -An -N4 -tu4 < /dev/urandom | tr -d ' ')
      RANDOM_LINE=$((RANDOM_LINE % TOTAL_WALLPAPERS + 1))
      RANDOM_WALLPAPER=$(sed -n "${RANDOM_LINE}p" "$WALLPAPER_CACHE_FILE")
    else
      echo "No wallpapers found in $WALLPAPER_DIR"
      exit 1
    fi
    # Random transition between wipe, outer, and center with random wipe angle
    TRANSITION_TYPE=$(shuf -n 1 -e "wipe" "outer" "center")
    if [ "$TRANSITION_TYPE" = "wipe" ]; then
      WIPE_ANGLE=$((RANDOM % 360))
      swww img "$RANDOM_WALLPAPER" --transition-type wipe --transition-angle $WIPE_ANGLE --transition-fps 165 --transition-step 165
    else
      swww img "$RANDOM_WALLPAPER" --transition-type $TRANSITION_TYPE --transition-fps 165 --transition-step 165
    fi
  else
    # Find the selected wallpaper using cached list for better performance
    SELECTED_WALLPAPER=$(grep "/$SELECTED\." "$WALLPAPER_CACHE_FILE" | head -n 1)
    if [ -n "$SELECTED_WALLPAPER" ]; then
      # Random transition between wipe, outer, and center with random wipe angle
      TRANSITION_TYPE=$(shuf -n 1 -e "wipe" "outer" "center")
      if [ "$TRANSITION_TYPE" = "wipe" ]; then
        WIPE_ANGLE=$((RANDOM % 360))
        swww img "$SELECTED_WALLPAPER" --transition-type wipe --transition-angle $WIPE_ANGLE --transition-fps 165 --transition-step 165
      else
        swww img "$SELECTED_WALLPAPER" --transition-type $TRANSITION_TYPE --transition-fps 165 --transition-step 165
      fi
    fi
  fi
fi