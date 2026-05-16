#!/usr/bin/env bash
set -euo pipefail

# SpoiledMilk Skills installer
# Copies each skill from ./skills/ into ~/.claude/skills/

SKILLS_DEST="${HOME}/.claude/skills"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: $SRC_DIR not found. Run this from the repo root." >&2
  exit 1
fi

mkdir -p "$SKILLS_DEST"

installed=0
skipped=0

for skill in "$SRC_DIR"/*/; do
  name=$(basename "$skill")
  dest="$SKILLS_DEST/$name"

  if [[ -d "$dest" ]]; then
    printf "Skill '%s' already exists at %s. Overwrite? [y/N] " "$name" "$dest"
    read -r ans
    if [[ "${ans:-N}" != "y" && "${ans:-N}" != "Y" ]]; then
      echo "  skipped $name"
      skipped=$((skipped + 1))
      continue
    fi
    rm -rf "$dest"
  fi

  cp -r "$skill" "$dest"
  echo "  installed $name"
  installed=$((installed + 1))
done

echo ""
echo "Done. $installed installed, $skipped skipped."
echo "Restart Claude Code if it was already running so it picks up the new skills."
