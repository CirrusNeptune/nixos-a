#!/usr/bin/env bash
set -euo pipefail

FILE="modules/services/scritch.nix"
LINE=12

# Extract current number and increment
current=$(sed -n "${LINE}p" "$FILE" | grep -oP 'Noop \K[0-9]+')
next=$((current + 1))

# Replace in-place
sed -i "${LINE}s/Noop ${current}/Noop ${next}/" "$FILE"

echo "Bumped Noop $current -> $next"

git add "$FILE"
git commit --amend --no-edit
git push -f
