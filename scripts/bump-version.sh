#!/usr/bin/env bash
set -euo pipefail

PLUGIN_JSON=".claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# Parse bump type from args (default: patch)
BUMP_TYPE="patch"
for arg in "$@"; do
  case $arg in
    --major) BUMP_TYPE="major" ;;
    --minor) BUMP_TYPE="minor" ;;
    --patch) BUMP_TYPE="patch" ;;
  esac
done

# Read current version from plugin.json
CURRENT=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Compute new version
case $BUMP_TYPE in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping $CURRENT → $NEW_VERSION ($BUMP_TYPE)"

# Update plugin.json
python3 - <<EOF
import json
with open('$PLUGIN_JSON', 'r') as f:
    data = json.load(f)
data['version'] = '$NEW_VERSION'
with open('$PLUGIN_JSON', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
EOF

# Update marketplace.json (nested: plugins[0].version)
python3 - <<EOF
import json
with open('$MARKETPLACE_JSON', 'r') as f:
    data = json.load(f)
data['plugins'][0]['version'] = '$NEW_VERSION'
with open('$MARKETPLACE_JSON', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
EOF

# Commit
git add "$PLUGIN_JSON" "$MARKETPLACE_JSON"
git commit -m "chore: bump version to $NEW_VERSION

Co-Authored-By: Claude <noreply@anthropic.com>"

# Tag and push
git tag "v${NEW_VERSION}"
git push
git push origin "v${NEW_VERSION}"

echo "Done: v${NEW_VERSION} pushed. GitHub Actions will create the release."
