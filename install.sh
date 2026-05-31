#!/usr/bin/env bash
# install.sh — TKB Plugin Full Installer
#
# Sets up everything required to run all tkb skills:
#   tkb-ingest, tkb-qa, tkb-lint, tkb-remove, tkb-link, tkb-agents
#
# Usage:
#   bash ~/.claude/plugins/marketplaces/tkb/install.sh [--vault-path /path/to/vault]
#
# Default vault path: $HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
DEFAULT_VAULT="${HOME}/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB"
VAULT="${DEFAULT_VAULT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault-path=*) VAULT="${1#--vault-path=}"; shift ;;
    --vault-path)   VAULT="${2}"; shift 2 ;;
    *) shift ;;
  esac
done

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_WORKSPACE="${HOME}/SAPDevelop/Work/agent-summary"
VERSION=$(python3 -c "import json; print(json.load(open('${PLUGIN_DIR}/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
created() { echo -e "  ${CYAN}+${NC} $*"; }
warn()    { echo -e "  ${YELLOW}!${NC} $*"; }

echo ""
echo "==> TKB Plugin Installer v${VERSION}"
echo "    Vault: ${VAULT}"
echo "    Plugin: ${PLUGIN_DIR}"
echo ""

# ── 1. TKB Vault directory structure ─────────────────────────────────────────
echo "── Vault structure"

dirs=(
  "triage/web"
  "triage/xiaohongshu"
  "raw/web"
  "raw/git"
  "raw/video/youtube"
  "raw/video/bilibili"
  "wiki/concepts"
  "wiki/analysis"
  "output"
)

for dir in "${dirs[@]}"; do
  path="${VAULT}/${dir}"
  if [[ ! -d "${path}" ]]; then
    mkdir -p "${path}"
    created "${dir}/"
  else
    ok "${dir}/"
  fi
done

# ── 2. wiki/_index.md (only if vault is fresh) ───────────────────────────────
INDEX="${VAULT}/wiki/_index.md"
if [[ ! -f "${INDEX}" ]]; then
  TODAY=$(date +%Y-%m-%dT%H:%M:%S%z)
  cat > "${INDEX}" << EOF
---
title: TKB Index
updated: ${TODAY}
total_entries: 0
---

# TKB Index

> 知识库统一索引。每个条目包含轻量摘要和标签，用于快速定位。
> 由 \`tkb-ingest\` 和 \`tkb-agents\` 自动维护，请勿手动编辑。

## 最近入库

EOF
  created "wiki/_index.md"
else
  ok "wiki/_index.md (exists, not overwritten)"
fi

# ── 3. CLAUDE.md (only if vault is fresh) ────────────────────────────────────
CLAUDE_MD="${VAULT}/CLAUDE.md"
if [[ ! -f "${CLAUDE_MD}" ]]; then
  warn "CLAUDE.md not found — creating minimal version"
  cat > "${CLAUDE_MD}" << 'EOF'
# CLAUDE.md

This file provides guidance to Claude Code when working with the TKB vault.

## What is TKB

An Obsidian-based personal knowledge base driven by Claude Code Skills.
Core principle: **Raw → Compiled Wiki** — LLM ingests source material and
compiles it into structured wiki notes.

## Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| `tkb-ingest` | `/tkb-ingest [work|ttt] <URL>` | Ingest URL/Git/video + compile |
| `tkb-agents` | `/tkb-agents [work|ttt]` | Ingest pasted article + bilingual notes |
| `tkb-qa` | `/tkb-qa [work:|ttt:] <question>` | Query knowledge base |
| `tkb-lint` | `/tkb-lint` | Health check |
| `tkb-remove` | `/tkb-remove <path>` | Delete entry + cleanup |
| `tkb-link` | `/tkb-link` | Cross-concept association scan |

## Source Tags

- `#work` — work-related knowledge
- `#ttt` — personal learning
EOF
  created "CLAUDE.md"
else
  ok "CLAUDE.md (exists, not overwritten)"
fi

# ── 4. tkb-agents workspace (agent-summary) ───────────────────────────────────
echo ""
echo "── tkb-agents workspace"

INBOX="${AGENT_WORKSPACE}/inbox.md"
AGENT_CLAUDE_MD="${AGENT_WORKSPACE}/CLAUDE.md"
SENTINEL="<!-- tkb-agents inbox — paste article content below this line, then run /tkb-agents [work|ttt] -->"

if [[ ! -d "${AGENT_WORKSPACE}" ]]; then
  mkdir -p "${AGENT_WORKSPACE}"
  created "${AGENT_WORKSPACE}"
else
  ok "${AGENT_WORKSPACE}"
fi

if [[ ! -f "${INBOX}" ]]; then
  printf '%s\n' "${SENTINEL}" > "${INBOX}"
  created "inbox.md"
else
  ok "inbox.md (exists, not overwritten)"
fi

if [[ ! -f "${AGENT_CLAUDE_MD}" ]]; then
  cat > "${AGENT_CLAUDE_MD}" << EOF
# agent-summary

Workspace for \`/tkb-agents\` — paste English web articles into \`inbox.md\`,
then run \`/tkb-agents [work|ttt]\` to translate, archive, and ingest into TKB.

## How to use

1. Paste article content into \`inbox.md\` (below the sentinel comment)
2. Run \`/tkb-agents work\` or \`/tkb-agents ttt\`

## TKB Vault

\`${VAULT}\`
EOF
  created "CLAUDE.md"
else
  ok "CLAUDE.md (exists, not overwritten)"
fi

# ── 5. yt-dlp (required by tkb-ingest for YouTube/Bilibili) ──────────────────
echo ""
echo "── Dependencies"

if command -v yt-dlp &>/dev/null; then
  ok "yt-dlp $(yt-dlp --version)"
else
  warn "yt-dlp not found — installing via brew"
  if command -v brew &>/dev/null; then
    brew install yt-dlp
    ok "yt-dlp installed"
  else
    warn "brew not found — install yt-dlp manually: https://github.com/yt-dlp/yt-dlp#installation"
  fi
fi

if command -v ffmpeg &>/dev/null; then
  ok "ffmpeg (required by yt-dlp for subtitle merging)"
else
  warn "ffmpeg not found — install via brew: brew install ffmpeg"
fi

# ── 6. scripts/fetch_subtitle.sh permissions ─────────────────────────────────
FETCH_SCRIPT="${PLUGIN_DIR}/scripts/fetch_subtitle.sh"
if [[ -f "${FETCH_SCRIPT}" ]]; then
  chmod +x "${FETCH_SCRIPT}"
  ok "scripts/fetch_subtitle.sh (executable)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "Installation complete."
echo ""
echo "Quick start:"
echo "  tkb-ingest  → open vault in Claude Code, run: /tkb-ingest ttt <URL>"
echo "  tkb-agents  → paste article into ${INBOX}"
echo "               open ${AGENT_WORKSPACE} in Claude Code, run: /tkb-agents ttt"
echo ""
