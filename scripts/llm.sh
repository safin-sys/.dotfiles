#!/usr/bin/env bash
# run_model.sh — 3-pane llama.cpp server TUI
# Pure bash + coreutils.  Zero external deps.
#
#   Left   – file tree        ↑ ↓ → ← navigate/expand   Enter select
#   Middle – live server log
#   Right  – settings         c t p g edit   s start/stop   q quit
# ──────────────────────────────────────────────────────────────────────────────

# ─── CONFIG ───────────────────────────────────────────────────────────────────
MODELS_DIR="${MODELS_DIR:-/home/elliot/ai/models}"
LLAMA_SERVER="${LLAMA_SERVER:-/home/elliot/ai/llama.cpp/build/bin/llama-server}"

# ─── DEFAULTS ─────────────────────────────────────────────────────────────────
CTX=8192
THREADS=$(nproc)
PORT=8080
GPU_LAYERS=0      # 0 = CPU only; gets overwritten by auto-calc if GPU found
GPU_LAYERS_AUTO=1 # 1 = auto mode active; 0 = user has manually set a value
SELECTED_MODEL=""
SELECTED_MODEL_NAME=""

# ─── SANITY ───────────────────────────────────────────────────────────────────
[[ -d "$MODELS_DIR" ]] || {
  echo "Models dir not found: $MODELS_DIR"
  exit 1
}
[[ -x "$LLAMA_SERVER" ]] || {
  echo "llama-server not found: $LLAMA_SERVER"
  exit 1
}

# ─── TTY RAW MODE ─────────────────────────────────────────────────────────────
ORIG_STTY=$(stty -g)
stty -echo -icanon min 0 time 1
_restore_tty() { stty "$ORIG_STTY" 2>/dev/null; }
trap _restore_tty EXIT

# ─── REGEX ────────────────────────────────────────────────────────────────────
RE_ERROR='[Ee][Rr][Rr][Oo][Rr]'
RE_CMD='^[[:space:]]*\$'

# ─── CONTEXT HELPERS ──────────────────────────────────────────────────────────
parse_ctx() {
  case "${1,,}" in
  1k) echo 1024 ;; 2k) echo 2048 ;; 4k) echo 4096 ;;
  8k) echo 8192 ;; 16k) echo 16384 ;; 32k) echo 32768 ;;
  64k) echo 65536 ;; 128k) echo 131072 ;;
  [0-9]*) echo "$1" ;;
  *) echo "" ;;
  esac
}
ctx_display() {
  case "$1" in
  1024) echo "1k" ;; 2048) echo "2k" ;; 4096) echo "4k" ;; 8192) echo "8k" ;;
  16384) echo "16k" ;; 32768) echo "32k" ;; 65536) echo "64k" ;; 131072) echo "128k" ;;
  *) echo "$1" ;;
  esac
}

# ─── FILE SIZE (pure bash, no bc) ─────────────────────────────────────────────
human_size() {
  local bytes=$1
  if ((bytes >= 1073741824)); then
    local v=$((bytes * 10 / 1073741824))
    echo "${v:0:-1}.${v: -1} GB"
  elif ((bytes >= 1048576)); then
    local v=$((bytes * 10 / 1048576))
    echo "${v:0:-1}.${v: -1} MB"
  else
    echo "$((bytes / 1024)) KB"
  fi
}

# ─── GPU / VRAM DETECTION ─────────────────────────────────────────────────────
# Runs once at startup.  Sets VRAM_MB (total VRAM in megabytes) and GPU_NAME.
# Falls back through: nvidia-smi → rocm-smi → sysfs → 0 (no GPU).
VRAM_MB=0
GPU_NAME=""

_detect_gpu() {
  local line
  # ── NVIDIA ──
  if command -v nvidia-smi &>/dev/null; then
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    [[ -n "$VRAM_MB" && "$VRAM_MB" =~ ^[0-9]+$ ]] && return
    VRAM_MB=0
    GPU_NAME=""
  fi
  # ── AMD (rocm-smi) ──
  if command -v rocm-smi &>/dev/null; then
    # rocm-smi --showmeminfo prints lines like "Total Memory: 8192 MB"
    line=$(rocm-smi --showmeminfo 2>/dev/null | grep -i 'Total Memory' | head -1)
    if [[ -n "$line" ]]; then
      VRAM_MB=$(echo "$line" | awk '{print $(NF-1)}')
      GPU_NAME=$(rocm-smi --showgfxversion 2>/dev/null | head -1 || echo "AMD GPU")
      [[ "$VRAM_MB" =~ ^[0-9]+$ ]] && return
    fi
    VRAM_MB=0
    GPU_NAME=""
  fi
  # ── sysfs fallback (works for both NVIDIA & AMD on newer kernels) ──
  local memfile
  for memfile in /sys/class/drm/card[0-9]*/device/mem_info; do
    [[ -f "$memfile" ]] || continue
    line=$(grep -i 'bo_size\|total' "$memfile" 2>/dev/null | head -1)
    if [[ -n "$line" ]]; then
      # value is in bytes
      local raw
      raw=$(echo "$line" | awk '{print $NF}')
      if [[ "$raw" =~ ^[0-9]+$ ]]; then
        VRAM_MB=$((raw / 1048576))
        GPU_NAME="GPU (sysfs)"
        return
      fi
    fi
  done
  VRAM_MB=0
  GPU_NAME=""
}
_detect_gpu

# ─── GGUF LAYER-COUNT EXTRACTION ─────────────────────────────────────────────
# Reads "llm.n_layers" from the GGUF key-value metadata.
# Only scans the first 1 MB of the file — the header is always at the front.
# Returns 0 (sets nothing) if extraction fails.
_read_n_layers() {
  local file="$1"
  [[ -f "$file" ]] || {
    MODEL_N_LAYERS=0
    return
  }

  # grep -boa: print byte offset of match.  Search first 1MB only via head.
  local offset
  offset=$(head -c 1048576 "$file" | grep -boa 'llm.n_layers' | head -1 | cut -d: -f1)
  if [[ -z "$offset" || ! "$offset" =~ ^[0-9]+$ ]]; then
    MODEL_N_LAYERS=0
    return
  fi

  # layout after key: uint32 value_type (4 bytes) + uint32 value (4 bytes)
  local val_offset=$((offset + 12 + 4)) # 12 = len("llm.n_layers"), 4 = skip type field
  local layers
  layers=$(dd if="$file" bs=1 skip=$val_offset count=4 2>/dev/null | od -A n -t u4 | tr -d ' ')

  if [[ -n "$layers" && "$layers" =~ ^[0-9]+$ && "$layers" -gt 0 && "$layers" -lt 1000 ]]; then
    MODEL_N_LAYERS=$layers
  else
    MODEL_N_LAYERS=0
  fi
}
MODEL_N_LAYERS=0

# ─── GPU LAYER AUTO-CALCULATION ──────────────────────────────────────────────
# Called whenever the selected model changes (or VRAM changes).
# Sets GPU_LAYERS to the calculated value if auto mode is on.
# Formula: usable_vram = VRAM * 0.90   (leave 10% headroom for KV cache etc)
#          bytes_per_layer = model_size / n_layers
#          gpu_layers = min( usable_vram / bytes_per_layer,  n_layers )
_calc_gpu_layers() {
  if ((VRAM_MB == 0 || MODEL_N_LAYERS == 0)); then
    GPU_LAYERS=0
    return
  fi
  local model_bytes model_mb usable bpl calc
  model_bytes=$(stat -c%s "$SELECTED_MODEL" 2>/dev/null || echo 0)
  ((model_bytes == 0)) && {
    GPU_LAYERS=0
    return
  }
  model_mb=$((model_bytes / 1048576))
  ((model_mb == 0)) && {
    GPU_LAYERS=0
    return
  }

  usable=$((VRAM_MB * 90 / 100))
  bpl=$((model_mb / MODEL_N_LAYERS))
  ((bpl == 0)) && bpl=1
  calc=$((usable / bpl))
  ((calc > MODEL_N_LAYERS)) && calc=$MODEL_N_LAYERS
  GPU_LAYERS=$calc
}

# ─── COLOUR CODES ─────────────────────────────────────────────────────────────
R0='\e[0m'
DM='\e[2m'
BD='\e[1m'
CY='\e[0;36m'
CYB='\e[1;36m'
GR='\e[0;32m'
GRB='\e[1;32m'
YL='\e[1;33m'
RD='\e[0;31m'
RDB='\e[1;31m'
WH='\e[0;37m'
BG_NAVY='\e[48;5;17m'
BG_SEL='\e[48;5;22m'
FG_SEL='\e[38;5;231m'

# ─── FILE-TREE ────────────────────────────────────────────────────────────────
declare -a T_PATH T_DEPTH T_ISDIR T_OPEN T_NAME T_SIZE
T_N=0

_scan() {
  local dir="$1" depth="$2" entry sz
  while IFS= read -r -d '' entry; do
    if find "$entry" -maxdepth 5 -iname '*.gguf' -print -quit 2>/dev/null | grep -q .; then
      T_PATH[$T_N]="$entry"
      T_DEPTH[$T_N]=$depth
      T_ISDIR[$T_N]=1
      T_OPEN[$T_N]=1
      T_NAME[$T_N]=$(basename "$entry")
      T_SIZE[$T_N]=""
      ((T_N++))
      _scan "$entry" $((depth + 1))
    fi
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null | sort -z)

  while IFS= read -r -d '' entry; do
    sz=$(stat -c%s "$entry" 2>/dev/null || echo 0)
    T_PATH[$T_N]="$entry"
    T_DEPTH[$T_N]=$depth
    T_ISDIR[$T_N]=0
    T_OPEN[$T_N]=0
    T_NAME[$T_N]=$(basename "$entry")
    T_SIZE[$T_N]=$(human_size "$sz")
    ((T_N++))
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -type f -iname '*.gguf' -print0 2>/dev/null | sort -z)
}
_scan "$MODELS_DIR" 0
((T_N == 0)) && {
  echo "No .gguf models found under $MODELS_DIR"
  exit 1
}

# ─── VISIBLE-TREE ─────────────────────────────────────────────────────────────
declare -a VT
VT_N=0
CURSOR=0
SCROLL=0

_rebuild_vt() {
  VT=()
  VT_N=0
  local skip=-1 i
  for ((i = 0; i < T_N; i++)); do
    if ((skip >= 0)); then
      ((T_DEPTH[$i] > skip)) && continue
      skip=-1
    fi
    VT[$VT_N]=$i
    ((VT_N++))
    ((T_ISDIR[$i] == 1 && T_OPEN[$i] == 0)) && skip=${T_DEPTH[$i]}
  done
  ((CURSOR >= VT_N)) && CURSOR=$((VT_N - 1))
  ((CURSOR < 0)) && CURSOR=0
}
_rebuild_vt

# ─── LOG BUFFER ───────────────────────────────────────────────────────────────
declare -a LOG
LOG_N=0
LOG_MAX=600
LOG_FILE=""
LOG_POS=0

_log() {
  LOG[$LOG_N]="$1"
  ((LOG_N++))
  if ((LOG_N > LOG_MAX)); then
    local half=$((LOG_MAX / 2)) i
    for ((i = 0; i < LOG_MAX - half; i++)); do LOG[$i]=${LOG[$((i + half))]}; done
    LOG_N=$((LOG_MAX - half))
  fi
  DIRTY_MID=1
}

_poll_log() {
  [[ -z "$SERVER_PID" || -z "$LOG_FILE" || ! -f "$LOG_FILE" ]] && return
  local line new_pos
  new_pos=$(wc -l <"$LOG_FILE")
  ((new_pos == LOG_POS)) && return
  while IFS= read -r line; do _log "  $line"; done < <(tail -n +"$((LOG_POS + 1))" "$LOG_FILE")
  LOG_POS=$new_pos
}

# ─── SERVER ───────────────────────────────────────────────────────────────────
SERVER_PID=""

_srv_running() { [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; }

_srv_start() {
  _srv_running && {
    _srv_stop
    sleep 0.2
  }
  [[ -z "$SELECTED_MODEL" ]] && {
    _log "  [!] select a model first"
    DIRTY_RIGHT=1
    return
  }
  LOG_FILE=$(mktemp)
  LOG_POS=0
  local cmd=("$LLAMA_SERVER" --model "$SELECTED_MODEL" --ctx-size "$CTX" --threads "$THREADS" --port "$PORT" --host 0.0.0.0 --context-shift --webui-mcp-proxy --no-webui-mcp-proxy)
  ((GPU_LAYERS > 0)) && cmd+=(--n-gpu-layers "$GPU_LAYERS")
  _log ""
  _log "  \$ ${cmd[*]}"
  _log ""
  "${cmd[@]}" >"$LOG_FILE" 2>&1 &
  SERVER_PID=$!
  DIRTY_RIGHT=1
}

_srv_stop() {
  if _srv_running; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
    _log "  [server stopped]"
  fi
  SERVER_PID=""
  DIRTY_RIGHT=1
}

# ─── LAYOUT ───────────────────────────────────────────────────────────────────
ROWS=$(tput lines)
COLS=$(tput cols)
LW=$((COLS * 28 / 100))
RW=$((COLS * 30 / 100))
MW=$((COLS - LW - RW))
CH=$((ROWS - 2))

# ─── DIRTY FLAGS ──────────────────────────────────────────────────────────────
DIRTY_LEFT=1
DIRTY_MID=1
DIRTY_RIGHT=1

# ─── FRAME BUFFER ─────────────────────────────────────────────────────────────
FRAME=""
_fmv() { FRAME+="\e[${1};${2}H"; }
_fcl() { FRAME+="\e[K"; }
_fstr() { FRAME+="$1"; }

# ─── BUILD LEFT ───────────────────────────────────────────────────────────────
_build_left() {
  ((CURSOR < SCROLL)) && SCROLL=$CURSOR
  ((CURSOR >= SCROLL + CH)) && SCROLL=$((CURSOR - CH + 1))

  local row=2 i vi idx depth isdir open indent icon label maxw
  for ((i = 0; i < CH; i++)); do
    vi=$((SCROLL + i))
    _fmv $row 1
    if ((vi < VT_N)); then
      idx=${VT[$vi]}
      depth=${T_DEPTH[$idx]}
      isdir=${T_ISDIR[$idx]}
      open=${T_OPEN[$idx]}

      indent=""
      for ((_d = 0; _d < depth; _d++)); do indent+="  "; done
      if ((isdir)); then ((open)) && icon="▾ " || icon="▸ "; else icon="  "; fi

      label="${indent}${icon}${T_NAME[$idx]}"
      ((isdir == 0)) && label+=" ${T_SIZE[$idx]}"

      maxw=$((LW - 1))
      ((${#label} > maxw)) && label="${label:0:$((maxw - 1))}…"

      if ((vi == CURSOR)); then
        [[ "${T_PATH[$idx]}" == "$SELECTED_MODEL" ]] &&
          _fstr "${BG_SEL}${FG_SEL}${BD}" ||
          _fstr "${BG_NAVY}${CYB}"
      elif [[ "${T_PATH[$idx]}" == "$SELECTED_MODEL" ]]; then
        _fstr "${GRB}"
      elif ((isdir)); then
        _fstr "${DM}${WH}"
      else
        _fstr "${WH}"
      fi
      _fstr "$label"
      _fcl
      _fstr "${R0}"
    else
      _fcl
    fi
    ((row++))
  done
}

# ─── BUILD MID ────────────────────────────────────────────────────────────────
_build_mid() {
  local col=$((LW + 1)) row=2 i start line
  # max width for mid content: stop before the right pane starts
  local mid_max=$((MW - 1))

  _fmv 2 $col
  _fstr "${CY}${BD}  server log"
  _fcl
  _fstr "${R0}"
  row=3

  start=$((LOG_N - CH + 1))
  ((start < 0)) && start=0

  for ((i = start; i < LOG_N && row < ROWS; i++)); do
    _fmv $row $col
    line="${LOG[$i]}"
    ((${#line} > mid_max)) && line="${line:0:$((mid_max - 1))}…"
    if [[ "$line" =~ $RE_ERROR ]]; then
      _fstr "${RD}${line}${R0}"
    elif [[ "$line" =~ $RE_CMD ]]; then
      _fstr "${YL}${line}${R0}"
    else
      _fstr "${DM}${line}${R0}"
    fi
    _fcl
    ((row++))
  done
  # blank remaining rows — BUT only up to mid_max columns, not the full line.
  # We do this by writing mid_max spaces instead of \e[K (which clears to EOL).
  local blank=""
  for ((i = 0; i < mid_max; i++)); do blank+=" "; done
  while ((row < ROWS)); do
    _fmv $row $col
    _fstr "$blank"
    ((row++))
  done
}

# ─── BUILD RIGHT ──────────────────────────────────────────────────────────────
_build_right() {
  local col=$((LW + MW + 1)) row=2 mname running=0
  _srv_running && running=1

  # header
  _fmv $row $col
  _fstr "${CY}${BD}  settings"
  _fcl
  _fstr "${R0}"
  ((row++))

  # status badge
  _fmv $row $col
  if ((running)); then
    _fstr "  ${GRB}● running${R0} on :${PORT}"
  else
    _fstr "  ${RDB}● stopped${R0}"
  fi
  _fcl
  ((row += 2))

  # model
  _fmv $row $col
  _fstr "${DM}  model${R0}"
  _fcl
  ((row++))
  _fmv $row $col
  if [[ -n "$SELECTED_MODEL" ]]; then
    mname="$SELECTED_MODEL_NAME"
    ((${#mname} > RW - 4)) && mname="${mname:0:$((RW - 6))}…"
    _fstr "    ${GR}${mname}${R0}"
  else
    _fstr "    ${DM}(none)${R0}"
  fi
  _fcl
  ((row += 2))

  # settings
  _fmv $row $col
  _fstr "${DM}  context  ${R0}${WH}$(ctx_display "$CTX")${R0}  ${DM}[c]${R0}"
  _fcl
  ((row++))
  _fmv $row $col
  _fstr "${DM}  threads  ${R0}${WH}${THREADS}${R0}  ${DM}[t]${R0}"
  _fcl
  ((row++))
  _fmv $row $col
  _fstr "${DM}  port     ${R0}${WH}${PORT}${R0}  ${DM}[p]${R0}"
  _fcl
  ((row++))

  # gpu layers row — shows "auto (N)" or the manual value
  _fmv $row $col
  if ((VRAM_MB == 0)); then
    # no GPU detected at all
    _fstr "${DM}  gpu off  ${R0}${WH}0${R0}  ${DM}(no GPU)${R0}"
  elif ((GPU_LAYERS_AUTO)); then
    _fstr "${DM}  gpu off  ${R0}${GR}auto ${WH}${GPU_LAYERS}${R0}  ${DM}[g]${R0}"
  else
    _fstr "${DM}  gpu off  ${R0}${WH}${GPU_LAYERS}${R0}  ${DM}[g] [a]auto${R0}"
  fi
  _fcl
  ((row += 1))

  # gpu info line (small, dim)
  _fmv $row $col
  if ((VRAM_MB > 0)); then
    _fstr "    ${DM}${GPU_NAME} · ${VRAM_MB} MB"
    if [[ -n "$SELECTED_MODEL" && MODEL_N_LAYERS -gt 0 ]]; then
      _fstr " · ${MODEL_N_LAYERS} layers"
    fi
    _fstr "${R0}"
  fi
  _fcl
  ((row += 2))

  # action
  _fmv $row $col
  if ((running)); then
    _fstr "  ${RDB}[s] stop server${R0}"
  else
    _fstr "  ${GRB}[s] start server${R0}"
  fi
  _fcl
  ((row++))
  _fmv $row $col
  _fstr "  ${DM}[q] quit${R0}"
  _fcl
  ((row++))

  # clear remaining rows in the right pane
  while ((row < ROWS)); do
    _fmv $row $col
    _fcl
    ((row++))
  done
}

# ─── INLINE EDIT ──────────────────────────────────────────────────────────────
EDIT_RESULT=""
_edit() {
  local label="$1" buf="$2" hint="$3"
  local col=$((LW + MW + 1)) row=$((ROWS - 2)) key seq

  while true; do
    printf "\e[%d;%dH${YL}  %s: ${R0}${WH}%s${R0}\e[K" $row $col "$label" "$buf"
    printf "\e[%d;%dH${DM}  %s${R0}\e[K" $((row + 1)) $col "$hint"

    IFS= read -r -s -N 1 -t 0.15 key
    [[ -z "$key" ]] && continue

    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -r -s -N 1 -t 0.05 seq
      if [[ -z "$seq" ]]; then
        EDIT_RESULT=""
        printf "\e[%d;%dH\e[K\e[%d;%dH\e[K" $row $col $((row + 1)) $col
        DIRTY_RIGHT=1
        DIRTY_MID=1
        return
      fi
      [[ "$seq" == "[" ]] && { IFS= read -r -s -N 1 -t 0.05 seq; }
      continue
    fi

    case "$key" in
    $'\r' | $'\n')
      EDIT_RESULT="$buf"
      printf "\e[%d;%dH\e[K\e[%d;%dH\e[K" $row $col $((row + 1)) $col
      DIRTY_RIGHT=1
      return
      ;;
    $'\x7f' | $'\x08') ((${#buf} > 0)) && buf="${buf:0:$((${#buf} - 1))}" ;;
    [[:print:]]) buf+="$key" ;;
    esac
  done
}

# ─── CLEANUP ──────────────────────────────────────────────────────────────────
_cleanup() {
  _srv_stop
  printf "\e[?25h\e[2J\e[H"
  tput sgr0
  stty "$ORIG_STTY" 2>/dev/null
  [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] && rm -f "$LOG_FILE"
}
trap _cleanup EXIT INT TERM

# ─── MAIN ─────────────────────────────────────────────────────────────────────
printf "\e[?25l\e[2J" # hide cursor, clear screen

# top + bottom bars — static, drawn once
printf "\e[1;1H${BG_NAVY}${CYB} llama.cpp server launcher"
printf "%*s${R0}" $((COLS - 27)) ""
printf "\e[%d;1H${BG_NAVY}${DM}${WH} ↑↓ navigate   →← expand/collapse   Enter select   s start/stop   c t p g [a]auto   q quit" "$ROWS"
printf "%*s${R0}" $((COLS - 90 > 0 ? COLS - 90 : 0)) ""

key="" seq="" idx="" parsed=""

while true; do
  _poll_log

  FRAME=""
  ((DIRTY_LEFT)) && {
    _build_left
    DIRTY_LEFT=0
  }
  ((DIRTY_MID)) && {
    _build_mid
    DIRTY_MID=0
  }
  ((DIRTY_RIGHT)) && {
    _build_right
    DIRTY_RIGHT=0
  }
  [[ -n "$FRAME" ]] && printf "%b" "$FRAME"

  # ── read exactly 1 byte, block up to 100ms ──
  IFS= read -r -s -N 1 -t 0.1 key
  [[ -z "$key" ]] && continue

  # ── escape sequences (arrows) ──
  if [[ "$key" == $'\x1b' ]]; then
    IFS= read -r -s -N 1 -t 0.05 seq
    if [[ "$seq" == "[" ]]; then
      IFS= read -r -s -N 1 -t 0.05 seq
      idx=${VT[$CURSOR]}
      case "$seq" in
      A)
        ((CURSOR > 0)) && ((CURSOR--))
        DIRTY_LEFT=1
        ;;
      B)
        ((CURSOR < VT_N - 1)) && ((CURSOR++))
        DIRTY_LEFT=1
        ;;
      C) ((T_ISDIR[$idx] == 1 && T_OPEN[$idx] == 0)) && {
        T_OPEN[$idx]=1
        _rebuild_vt
        DIRTY_LEFT=1
      } ;;
      D) ((T_ISDIR[$idx] == 1 && T_OPEN[$idx] == 1)) && {
        T_OPEN[$idx]=0
        _rebuild_vt
        DIRTY_LEFT=1
      } ;;
      esac
    fi
    continue
  fi

  # ── action keys ──
  case "$key" in
  $'\r' | $'\n')
    idx=${VT[$CURSOR]}
    if ((T_ISDIR[$idx] == 0)); then
      SELECTED_MODEL=${T_PATH[$idx]}
      SELECTED_MODEL_NAME=${T_NAME[$idx]}
      _log "  [selected] ${T_NAME[$idx]}"
      # read layer count from GGUF header, then recalc GPU layers if auto
      _read_n_layers "$SELECTED_MODEL"
      if ((GPU_LAYERS_AUTO && VRAM_MB > 0)); then
        _calc_gpu_layers
      fi
      DIRTY_LEFT=1
      DIRTY_RIGHT=1
    else
      ((T_OPEN[$idx])) && T_OPEN[$idx]=0 || T_OPEN[$idx]=1
      _rebuild_vt
      DIRTY_LEFT=1
    fi
    ;;
  s | S) _srv_running && _srv_stop || _srv_start ;;
  c | C)
    _edit "context" "$(ctx_display "$CTX")" "1k 2k 4k 8k 16k 32k 64k 128k  or a raw number"
    [[ -n "$EDIT_RESULT" ]] && {
      parsed=$(parse_ctx "$EDIT_RESULT")
      [[ -n "$parsed" ]] && CTX=$parsed
    }
    ;;
  t | T)
    _edit "threads" "$THREADS" "number  (1-$(nproc))"
    [[ -n "$EDIT_RESULT" && "$EDIT_RESULT" =~ ^[0-9]+$ ]] && THREADS=$EDIT_RESULT
    ;;
  p | P)
    _edit "port" "$PORT" "port  (1024-65535)"
    [[ -n "$EDIT_RESULT" && "$EDIT_RESULT" =~ ^[0-9]+$ ]] && PORT=$EDIT_RESULT
    ;;
  g | G)
    # manual override — switches off auto mode
    _edit "gpu layers" "$GPU_LAYERS" "0 = CPU only  (overrides auto)"
    if [[ -n "$EDIT_RESULT" && "$EDIT_RESULT" =~ ^[0-9]+$ ]]; then
      GPU_LAYERS=$EDIT_RESULT
      GPU_LAYERS_AUTO=0
    fi
    ;;
  a | A)
    # toggle auto back on and recalculate
    if ((GPU_LAYERS_AUTO)); then
      GPU_LAYERS_AUTO=0
      GPU_LAYERS=0
    else
      GPU_LAYERS_AUTO=1
      if [[ -n "$SELECTED_MODEL" && VRAM_MB -gt 0 ]]; then
        _read_n_layers "$SELECTED_MODEL"
        _calc_gpu_layers
      fi
    fi
    DIRTY_RIGHT=1
    ;;
  q | Q) break ;;
  esac
done
