#!/usr/bin/env bash
# find_wiki.sh — locate concept/analysis files in TKB wiki (supports subdirectories)
#
# Usage:
#   find_wiki.sh concepts              List all concept file paths (one per line)
#   find_wiki.sh analyses              List all analysis file paths (one per line)
#   find_wiki.sh concept  <name>       Find a single concept file by name (no .md suffix)
#   find_wiki.sh analysis <name>       Find a single analysis file by name (no -analysis.md suffix)
#
# Exit codes:
#   0  success (list mode: always; single mode: file found)
#   1  usage error
#   2  single mode: file not found

set -euo pipefail

TKB_ROOT="${TKB_ROOT:-/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB}"
CONCEPTS_DIR="$TKB_ROOT/wiki/concepts"
ANALYSES_DIR="$TKB_ROOT/wiki/analysis"

usage() {
  echo "Usage: $0 concepts|analyses|concept <name>|analysis <name>" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage

CMD="$1"

case "$CMD" in
  concepts)
    find "$CONCEPTS_DIR" -name "*.md" | sort
    ;;
  analyses)
    find "$ANALYSES_DIR" -name "*.md" | sort
    ;;
  concept)
    [[ $# -lt 2 ]] && { echo "Error: concept name required" >&2; exit 1; }
    NAME="$2"
    RESULT=$(find "$CONCEPTS_DIR" -name "${NAME}.md" | head -1)
    if [[ -n "$RESULT" ]]; then
      echo "$RESULT"
      exit 0
    else
      exit 2
    fi
    ;;
  analysis)
    [[ $# -lt 2 ]] && { echo "Error: analysis name required" >&2; exit 1; }
    NAME="$2"
    # support both "<name>" and "<name>-analysis" as input
    BASENAME="${NAME%-analysis}"
    RESULT=$(find "$ANALYSES_DIR" -name "${BASENAME}-analysis.md" | head -1)
    if [[ -n "$RESULT" ]]; then
      echo "$RESULT"
      exit 0
    else
      exit 2
    fi
    ;;
  *)
    usage
    ;;
esac
