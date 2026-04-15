#!/usr/bin/env bash
# =============================================================================
# scan_music.sh — Music File Integrity Scanner
# =============================================================================

MUSIC_DIR="${1:-$HOME/Music}"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

total=0; ok=0; mismatch=0; suspicious=0

check_deps() {
    local missing=()
    for cmd in file ffprobe python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        echo "Install with: sudo apt install file ffmpeg python3"
        exit 1
    fi
}

parse_probe() {
    # $1 = json string, $2 = field name
    python3 - "$1" "$2" <<'PY'
import sys, json
try:
    d = json.loads(sys.argv[1])
    field = sys.argv[2]
    streams = [x for x in d.get('streams', []) if x.get('codec_type') == 'audio']
    s = streams[0] if streams else {}
    fmt = d.get('format', {})
    if field == 'codec':
        print(s.get('codec_name', '?'))
    elif field == 'bitrate':
        val = s.get('bit_rate') or fmt.get('bit_rate') or '?'
        print(val)
    elif field == 'sample_rate':
        print(s.get('sample_rate', '?'))
    elif field == 'channels':
        print(s.get('channels', '?'))
    elif field == 'bit_depth':
        print(s.get('bits_per_raw_sample') or s.get('bits_per_coded_sample') or '?')
except Exception:
    print('?')
PY
}

check_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local ext="${filename##*.}"
    ext="${ext,,}"

    case "$ext" in
        mp3|flac|aac|m4a|ogg|opus|wav|wma|aiff|aif|alac|ape|wv|mka) ;;
        *) return ;;
    esac

    ((total++))

    local magic
    magic=$(file --brief --mime-type "$filepath" 2>/dev/null || echo "unknown")

    local probe
    probe=$(ffprobe -v quiet -show_streams -show_format -of json "$filepath" 2>/dev/null)

    if [[ -z "$probe" ]]; then
        echo -e "${YELLOW}⚠ UNREADABLE  ${NC}${filename}"
        ((suspicious++))
        return
    fi

    local actual_codec bitrate sample_rate channels bit_depth bitrate_kbps
    actual_codec=$(parse_probe "$probe" codec)
    bitrate=$(parse_probe "$probe" bitrate)
    sample_rate=$(parse_probe "$probe" sample_rate)
    channels=$(parse_probe "$probe" channels)
    bit_depth=$(parse_probe "$probe" bit_depth)

    bitrate_kbps="?"
    if [[ "$bitrate" =~ ^[0-9]+$ ]]; then
        bitrate_kbps=$(( bitrate / 1000 ))
    fi

    local status="OK"
    local issues=()

    case "$ext" in
        flac)
            if [[ "$actual_codec" != "flac" ]]; then
                issues+=("codec is '${actual_codec}', not FLAC")
            elif [[ "$bitrate_kbps" =~ ^[0-9]+$ ]] && (( bitrate_kbps <= 400 )); then
                issues+=("bitrate only ${bitrate_kbps}kbps — likely transcoded from lossy source (fake lossless)")
                status="SUSPICIOUS"
            fi
            ;;
        mp3)
            [[ "$actual_codec" != "mp3" ]] && issues+=("codec is '${actual_codec}', not MP3")
            ;;
        m4a|aac)
            [[ "$actual_codec" != "aac" && "$actual_codec" != "alac" ]] && \
                issues+=("codec is '${actual_codec}', expected AAC or ALAC")
            ;;
        ogg)
            [[ "$actual_codec" != "vorbis" && "$actual_codec" != "opus" ]] && \
                issues+=("codec is '${actual_codec}', expected Vorbis/Opus")
            ;;
        opus)
            [[ "$actual_codec" != "opus" ]] && issues+=("codec is '${actual_codec}', not Opus")
            ;;
        wav)
            [[ "$actual_codec" != "pcm_s16le" && "$actual_codec" != "pcm_s24le" && \
               "$actual_codec" != "pcm_s32le" && "$actual_codec" != "pcm_f32le" ]] && \
                issues+=("codec is '${actual_codec}', expected PCM")
            ;;
        wma)
            [[ "$actual_codec" != "wmav2" && "$actual_codec" != "wmav1" && \
               "$actual_codec" != "wmapro" ]] && \
                issues+=("codec is '${actual_codec}', expected WMA")
            ;;
        aiff|aif)
            [[ "$actual_codec" != "pcm_s16be" && "$actual_codec" != "pcm_s24be" ]] && \
                issues+=("codec is '${actual_codec}', expected PCM/AIFF")
            ;;
    esac

    case "$magic" in
        audio/*|video/*|application/octet-stream) ;;
        *)
            issues+=("MIME type is '${magic}' — not an audio type")
            ;;
    esac

    local info="${DIM}${actual_codec} | ${bitrate_kbps}kbps | ${sample_rate}Hz | ${channels}ch | ${bit_depth}bit${NC}"

    if [[ ${#issues[@]} -gt 0 ]]; then
        [[ "$status" == "OK" ]] && status="MISMATCH"
        local issue_str
        issue_str=$(IFS='; '; echo "${issues[*]}")
        if [[ "$status" == "SUSPICIOUS" ]]; then
            echo -e "${YELLOW}⚠ FAKE LOSSLESS  ${BOLD}${filename}${NC}"
            echo -e "  ${info}"
            echo -e "  ${YELLOW}↳ ${issue_str}${NC}"
            ((suspicious++))
        else
            echo -e "${RED}✗ MISMATCH       ${BOLD}${filename}${NC}"
            echo -e "  ${info}"
            echo -e "  ${RED}↳ ${issue_str}${NC}"
            ((mismatch++))
        fi
    else
        echo -e "${GREEN}✓ OK  ${NC}${filename}  ${info}"
        ((ok++))
    fi
}

main() {
    check_deps

    if [[ ! -d "$MUSIC_DIR" ]]; then
        echo -e "${RED}Directory not found: $MUSIC_DIR${NC}"
        echo "Usage: $0 [music_dir]"
        exit 1
    fi

    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║        Music File Integrity Scanner          ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo -e "  Scanning: ${MUSIC_DIR}\n"
    echo -e "────────────────────────────────────────────────────\n"

    while IFS= read -r -d '' f; do
        check_file "$f"
    done < <(find "$MUSIC_DIR" -type f \( \
        -iname "*.mp3"  -o -iname "*.flac" -o -iname "*.aac"  -o \
        -iname "*.m4a"  -o -iname "*.ogg"  -o -iname "*.opus" -o \
        -iname "*.wav"  -o -iname "*.wma"  -o -iname "*.aiff" -o \
        -iname "*.aif"  -o -iname "*.alac" -o -iname "*.ape"  -o \
        -iname "*.wv"   -o -iname "*.mka"  \
    \) -print0 | sort -z)

    echo -e "\n────────────────────────────────────────────────────"
    echo -e "${BOLD}DONE${NC}  —  ${total} files scanned"
    echo -e "  ${GREEN}✓ OK${NC}            : ${ok}"
    echo -e "  ${RED}✗ Mismatches${NC}    : ${mismatch}"
    echo -e "  ${YELLOW}⚠ Fake lossless${NC} : ${suspicious}"

    if (( mismatch + suspicious > 0 )); then
        echo -e "\n${BOLD}${RED}  ↑ Problem files listed above${NC}"
    else
        echo -e "\n${GREEN}  All files look legit!${NC}"
    fi
}

main "$@"
