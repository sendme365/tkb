---
name: tkb-bump
description: >-
  Bump the TKB plugin version and publish a release. Use this skill whenever
  the user wants to release, publish, deploy, or bump the version of the TKB
  plugin — including phrases like "出一个版本", "发布", "release", "publish",
  "bump version", "tag a release", or "push a new version". Supports patch
  (default), minor, and major bumps.
---

# TKB Bump

Runs `./scripts/bump-version.sh` to bump the version, commit, tag, and push.
GitHub Actions then creates the release automatically.

## Bump type rules

| User says | Flag to use |
|-----------|-------------|
| "patch", "bugfix", "小版本", or nothing specific | *(default — no flag)* |
| "minor", "feature", "功能版本" | `--minor` |
| "major", "breaking", "大版本" | `--major` |

## Steps

1. Confirm working directory is `/Users/I333878/.claude/plugins/marketplaces/tkb`
2. Run `git status`. If there are uncommitted changes:
   - Run `git diff` to review what changed
   - Stage and commit **all** changed files (use specific file names, not `-A`):
     ```bash
     git add <file1> <file2> ...
     git commit -m "$(cat <<'EOF'
     <concise description derived from the diff>

     Co-Authored-By: Claude <noreply@anthropic.com>
     EOF
     )"
     ```
   - Do this automatically — no need to ask the user first
3. Determine the bump type from user input (default: patch)
4. Run:
   ```bash
   cd /Users/I333878/.claude/plugins/marketplaces/tkb
   ./scripts/bump-version.sh [--minor|--major]
   ```
5. Report the old → new version and confirm that the tag was pushed

## After running

The script handles everything: updates both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, commits, tags `vX.Y.Z`, and pushes. GitHub Actions picks up the tag and creates the GitHub Release.

Do not run `gh pr create`, manually edit version files, or push tags by hand — the script is the only correct release path.
