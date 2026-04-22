#!/usr/bin/env bash
# fetch_subtitle.sh — Download subtitles for YouTube or Bilibili videos
#
# Usage:
#   fetch_subtitle.sh <URL> <OUTPUT_DIR> [LANG_PREF]
#
# Arguments:
#   URL         YouTube (youtube.com, youtu.be) or Bilibili (bilibili.com, b23.tv) URL
#   OUTPUT_DIR  Absolute path to the entry directory (created if needed)
#               Script writes subtitles/ inside it.
#   LANG_PREF   Optional. Comma-separated language codes for --sub-langs.
#               Defaults: YouTube → "en,zh-Hans,zh"  Bilibili → "zh-Hans,zh,en"
#
# Outputs (written to OUTPUT_DIR/subtitles/):
#   <lang>.srt        Raw SRT subtitle file
#   transcript.txt    Clean plain-text transcript (timestamps stripped, duplicates removed)
#
# Stdout:
#   Single-line JSON: {"platform","video_id","title","channel","duration","upload_date",
#                      "description","lang","srt_file","transcript_file"}
#
# Exit codes:
#   0  success
#   1  usage error
#   2  yt-dlp not found
#   3  URL not recognized as YouTube or Bilibili
#   4  no subtitles available
#   5  yt-dlp error (metadata fetch or download failed)

set -euo pipefail

# ── argument validation ────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  echo "usage: fetch_subtitle.sh <URL> <OUTPUT_DIR> [LANG_PREF]" >&2
  exit 1
fi

URL="$1"
OUTPUT_DIR="$2"
USER_LANG="${3:-}"

# ── dependency check ──────────────────────────────────────────────────────────
if ! command -v yt-dlp &>/dev/null; then
  echo "error: yt-dlp not found. Install with: pip install yt-dlp" >&2
  exit 2
fi

# ── platform detection ────────────────────────────────────────────────────────
PLATFORM=""
if echo "$URL" | grep -qE "(youtube\.com|youtu\.be)"; then
  PLATFORM="youtube"
elif echo "$URL" | grep -qE "(bilibili\.com|b23\.tv)"; then
  PLATFORM="bilibili"
else
  echo "error: unrecognized URL (expected YouTube or Bilibili): $URL" >&2
  exit 3
fi

# ── language preference ───────────────────────────────────────────────────────
if [[ -n "$USER_LANG" ]]; then
  LANG_PREF="$USER_LANG"
elif [[ "$PLATFORM" == "bilibili" ]]; then
  LANG_PREF="zh-Hans,zh,en"
else
  LANG_PREF="en,zh-Hans,zh"
fi

# ── prepare directories ───────────────────────────────────────────────────────
SUBS_DIR="$OUTPUT_DIR/subtitles"
mkdir -p "$SUBS_DIR"

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# ── fetch video metadata ──────────────────────────────────────────────────────
# Fetch each field separately to avoid pipe-character collisions in titles/descriptions.
_yt_field() {
  yt-dlp --no-warnings --print "$1" --no-playlist --skip-download "$URL" 2>/dev/null
}

VIDEO_ID=$(    _yt_field "%(id)s"              ) || { echo "error: yt-dlp failed to fetch metadata for: $URL" >&2; exit 5; }
VIDEO_TITLE=$( _yt_field "%(title)s"           )
CHANNEL=$(     _yt_field "%(channel)s"         )
DURATION=$(    _yt_field "%(duration_string)s" )
UPLOAD_DATE=$( _yt_field "%(upload_date)s"     )
DESCRIPTION=$( _yt_field "%(description)s"     )

# ── subtitle download: manual first, auto-generated fallback ──────────────────
download_subs() {
  local flag="$1"
  # Use || true: yt-dlp exits non-zero if any one language returns 429 or is
  # unavailable, even when other languages downloaded successfully. We check
  # file presence after the call instead of relying on exit code.
  # Redirect stdout to stderr so [info]/[download] lines don't pollute our JSON output.
  yt-dlp \
    --no-warnings \
    "$flag" \
    --convert-subs srt \
    --sub-langs "$LANG_PREF" \
    --skip-download \
    --no-playlist \
    --output "$TMPDIR_WORK/%(id)s.%(ext)s" \
    "$URL" >/dev/null 2>/dev/null || true
}

download_subs "--write-subs"
SRT_COUNT=$(find "$TMPDIR_WORK" -name "*.srt" | wc -l | tr -d ' ')

if [[ "$SRT_COUNT" -eq 0 ]]; then
  download_subs "--write-auto-subs"
  SRT_COUNT=$(find "$TMPDIR_WORK" -name "*.srt" | wc -l | tr -d ' ')
fi

# If yt-dlp left .vtt files (conversion requires ffmpeg to be triggered by
# a successful run), convert them manually here as a fallback.
if [[ "$SRT_COUNT" -eq 0 ]]; then
  for vtt in "$TMPDIR_WORK"/*.vtt; do
    [[ -f "$vtt" ]] || continue
    srt="${vtt%.vtt}.srt"
    ffmpeg -i "$vtt" "$srt" -y 2>/dev/null && SRT_COUNT=$((SRT_COUNT + 1)) || true
  done
fi

if [[ "$SRT_COUNT" -eq 0 ]]; then
  echo "error: no subtitles available for $URL (tried langs: $LANG_PREF)" >&2
  exit 4
fi

# ── pick best language match ──────────────────────────────────────────────────
CHOSEN_SRT=""
CHOSEN_LANG=""
IFS=',' read -ra LANGS <<< "$LANG_PREF"
for lang in "${LANGS[@]}"; do
  candidate=$(find "$TMPDIR_WORK" -name "*.$lang.srt" | head -1)
  if [[ -n "$candidate" ]]; then
    CHOSEN_SRT="$candidate"
    CHOSEN_LANG="$lang"
    break
  fi
done

# fallback: take whatever SRT exists
if [[ -z "$CHOSEN_SRT" ]]; then
  CHOSEN_SRT=$(find "$TMPDIR_WORK" -name "*.srt" | head -1)
  CHOSEN_LANG=$(basename "$CHOSEN_SRT" | sed 's/^[^.]*\.\(.*\)\.srt$/\1/')
fi

cp "$CHOSEN_SRT" "$SUBS_DIR/${CHOSEN_LANG}.srt"

# ── SRT → plain-text transcript ───────────────────────────────────────────────
# Step 1: Strip SRT sequence numbers, timestamp lines, blank lines
# Step 2: Deduplicate consecutive identical lines (YouTube auto-cap overlap)
# Step 3: Merge into paragraphs (~100 words each, split at sentence boundaries)
awk '
  /^[0-9]+$/ { next }
  /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9],[0-9]+ -->/ { next }
  /^[[:space:]]*$/ { next }
  { print }
' "$SUBS_DIR/${CHOSEN_LANG}.srt" \
| awk 'prev != $0 { print; prev = $0 }' \
| awk '
  {
    for (i = 1; i <= NF; i++) {
      w = $i
      line = (length(line) == 0) ? w : line " " w
      wc++
      if (wc >= 100 && (w ~ /[.!?]$/ || wc >= 120)) {
        print line
        print ""
        line = ""
        wc = 0
      }
    }
  }
  END { if (length(line) > 0) print line }
' > "$SUBS_DIR/transcript.txt"

# ── emit JSON to stdout ───────────────────────────────────────────────────────
json_esc() {
  printf '%s' "$1" \
    | tr '\n' ' ' \
    | sed 's/\\/\\\\/g' \
    | sed 's/"/\\"/g'
}

printf '{"platform":"%s","video_id":"%s","title":"%s","channel":"%s","duration":"%s","upload_date":"%s","description":"%s","lang":"%s","srt_file":"subtitles/%s.srt","transcript_file":"subtitles/transcript.txt"}\n' \
  "$PLATFORM" \
  "$VIDEO_ID" \
  "$(json_esc "$VIDEO_TITLE")" \
  "$(json_esc "$CHANNEL")" \
  "$DURATION" \
  "$UPLOAD_DATE" \
  "$(json_esc "$DESCRIPTION")" \
  "$CHOSEN_LANG" \
  "$CHOSEN_LANG"
