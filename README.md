# TKB Plugin

Personal Knowledge Base (个人知识库) skills for Claude Code.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| `ingest` | `/ingest [work\|ttt] <URL>` | Ingest source material + compile wiki |
| `qa` | `/qa [work:\|ttt:] <question>` | Query knowledge base |
| `tkb-lint` | `/tkb-lint` | Health check + report |
| `tkb-remove` | `/tkb-remove <path>` | Delete entry + cleanup |
| `tkb-link` | `/tkb-link` | Cross-concept association scan + fix |
| `agents` | `/agents [work\|ttt]` | Ingest pasted article (bilingual translate + lecture notes) |
| `tkb-move` | ~~deprecated~~ | No longer needed (single partition) |

## Architecture

```
Source (URL/file) → /ingest → triage/ → raw/ → wiki/
```

### Source Tags

- `#work` — work-related knowledge
- `#ttt` — personal learning

## Installation

This plugin is installed locally. Skills are automatically discovered from
`~/.claude/plugins/marketplaces/tkb/skills/`.
