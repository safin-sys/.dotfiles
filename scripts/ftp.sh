#!/usr/bin/env bash
set -euo pipefail

ARIA_OPTS="-c -x 8 -s 8 --auto-file-renaming=false"
ALLOWED_EXTENSIONS="avi|mkv|mp4|mp3|zip|rar|pdf|jpg|jpeg|png|gif|tar|gz|7z"

# ── Source map (extracted from http://172.16.50.4/) ──────────────────────────
declare -A SERVER_FOLDERS=(
  ["1-Movies"]="🎥 English Movies|http://172.16.50.7/DHAKA-FLIX-7/English%20Movies/
🎥 English Movies 1080p|http://172.16.50.14/DHAKA-FLIX-14/English%20Movies%20%281080p%29/
🎥 Hindi Movies|http://172.16.50.14/DHAKA-FLIX-14/Hindi%20Movies/
🎥 South Indian Movies|http://172.16.50.14/DHAKA-FLIX-14/SOUTH%20INDIAN%20MOVIES/South%20Movies/
🎥 South Movies Hindi Dubbed|http://172.16.50.14/DHAKA-FLIX-14/SOUTH%20INDIAN%20MOVIES/Hindi%20Dubbed/
🎥 Kolkata Bangla Movies|http://172.16.50.7/DHAKA-FLIX-7/Kolkata%20Bangla%20Movies/
🎥 Satyajit Ray Films|http://172.16.50.7/DHAKA-FLIX-7/Kolkata%20Bangla%20Movies/Satyajit%20Ray%20Films/
🎥 Foreign Language Movies|http://172.16.50.7/DHAKA-FLIX-7/Foreign%20Language%20Movies/
🎥 IMDb Top-250|http://172.16.50.14/DHAKA-FLIX-14/IMDb%20Top-250%20Movies/
🎥 3D Movies|http://172.16.50.7/DHAKA-FLIX-7/3D%20Movies/
🎬 Animation Movies|http://172.16.50.14/DHAKA-FLIX-14/Animation%20Movies/
🎬 Animation Movies 1080p|http://172.16.50.14/DHAKA-FLIX-14/Animation%20Movies%20%281080p%29/"

  ["2-TV & Series"]="📺 TV & WEB Series|http://172.16.50.12/DHAKA-FLIX-12/TV-WEB-Series/
🇰🇷 Korean TV & WEB Series|http://172.16.50.14/DHAKA-FLIX-14/KOREAN%20TV%20%26%20WEB%20Series/
🌀 Anime & Cartoon TV Series|http://172.16.50.9/DHAKA-FLIX-9/Anime%20%26%20Cartoon%20TV%20Series/
🎙️ Documentary|http://172.16.50.9/DHAKA-FLIX-9/Documentary/
🤼 WWE & AEW Wrestling|http://172.16.50.9/DHAKA-FLIX-9/WWE%20%26%20AEW%20Wrestling/
🏆 Awards & TV Shows|http://172.16.50.9/DHAKA-FLIX-9/Awards%20%26%20TV%20Shows/"

  ["3-Games"]="🎮 PC Games|http://172.16.50.8/DHAKA-FLIX-8/PC%20Games/
📱 Android Games|http://172.16.50.8/DHAKA-FLIX-8/Android%20Games/
🕹️ Console Games|http://172.16.50.8/DHAKA-FLIX-8/Console%20Games/"

  ["4-Software & Tutorials"]="💿 Software|http://172.16.50.8/DHAKA-FLIX-8/Software/
📚 Tutorials & Training|http://172.16.50.9/DHAKA-FLIX-9/Tutorial/"
)

# ── Step 1: pick category ─────────────────────────────────────────────────────
SELECTED_CAT=$(printf '%s\n' "${!SERVER_FOLDERS[@]}" | sort | fzf \
  --prompt="Pick a category: " \
  --preview-window=hidden \
  --header="Enter: select | Esc: exit")

[[ -z "$SELECTED_CAT" ]] && echo "Exiting." && exit 0

# ── Step 2: pick starting folder ──────────────────────────────────────────────
BASE_URL=$(echo "${SERVER_FOLDERS[$SELECTED_CAT]}" \
  | fzf --prompt="Pick a folder: " \
        --preview-window=hidden \
        --header="Enter: browse | Esc: exit" \
  | cut -d'|' -f2)

[[ -z "$BASE_URL" ]] && echo "Exiting." && exit 0

# ── HTML entity decoder ───────────────────────────────────────────────────────
html_entity_decode() {
  local str="$1"
  str="${str//&amp;/&}"
  str="${str//&lt;/<}"
  str="${str//&gt;/>}"
  str="${str//&quot;/\"}"
  str="${str//&#39;/\'}"
  echo "$str"
}

# ── Main browser/download loop ────────────────────────────────────────────────
while true; do
  echo "📂 $BASE_URL"
  PAGE=$(curl -fsSL "$BASE_URL")

  ITEMS=()
  DISPLAY_NAMES=()

  FALLBACK=$(echo "$PAGE" | grep -oP '<div id="fallback">.*?</div>' | tr '\n' ' ')

  while IFS='|' read -r href name; do
    [[ -z "$href" || "$href" == ".." || "$href" =~ ^# ]] && continue

    name=$(html_entity_decode "$name")

    if [[ "$href" == */ ]]; then
      ITEMS+=("$href")
      DISPLAY_NAMES+=("📁 $name")
    elif [[ "$href" =~ \.($ALLOWED_EXTENSIONS)$ ]]; then
      ITEMS+=("$href")
      DISPLAY_NAMES+=("📄 $name")
    fi
  done < <(echo "$FALLBACK" | grep -oP '<a href="\K[^"]+">([^<]+)' | sed 's/">/|/')

  [[ ${#ITEMS[@]} -eq 0 ]] && echo "⚠️  Empty" && read -p "Enter to retry..." && continue

  # Build fzf menu
  MENU=""
  for i in "${!ITEMS[@]}"; do
    MENU+="$i|${DISPLAY_NAMES[$i]}"$'\n'
  done

  CHOICE=$(echo -e "$MENU" | fzf --prompt="Select (Tab=multi, Enter=action, Esc=back): " \
    --multi \
    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
    --header="Ctrl-A: select all | Ctrl-D: deselect all | Tab: toggle | Enter: download/cd | Esc: go back" \
    --preview-window=hidden |
    cut -d'|' -f1)

  # Esc at root → go back to category picker
  if [[ -z "$CHOICE" ]]; then
    PARENT="${BASE_URL%/}"
    PARENT="${PARENT%/*}/"
    if [[ "$PARENT" == "$BASE_URL" || "$PARENT" == "http:/" || "$PARENT" == "https:/" ]]; then
      echo "At root. Exiting."
      exit 0
    fi
    BASE_URL="$PARENT"
    continue
  fi

  # Single selection: navigate into directory
  if [[ $(echo "$CHOICE" | wc -l) -eq 1 ]]; then
    IDX="$CHOICE"
    if [[ "${ITEMS[$IDX]}" == */ ]]; then
      if [[ "${ITEMS[$IDX]}" == /* ]]; then
        BASE_URL="$(echo "$BASE_URL" | grep -oP '^https?://[^/]+')${ITEMS[$IDX]}"
      else
        BASE_URL="${BASE_URL}${ITEMS[$IDX]}"
      fi
      continue
    fi
  fi

  # Download selected files
  TMP_LIST=$(mktemp)
  while read -r IDX; do
    ITEM="${ITEMS[$IDX]}"
    [[ "$ITEM" == */ ]] && continue

    if [[ "$ITEM" == /* ]]; then
      echo "$(echo "$BASE_URL" | grep -oP '^https?://[^/]+')${ITEM}" >>"$TMP_LIST"
    else
      echo "${BASE_URL}${ITEM}" >>"$TMP_LIST"
    fi
  done <<<"$CHOICE"

  if [[ -s "$TMP_LIST" ]]; then
    echo "⬇️  Downloading $(wc -l <"$TMP_LIST") file(s)..."
    aria2c $ARIA_OPTS -i "$TMP_LIST"
  fi
  rm -f "$TMP_LIST"
done
