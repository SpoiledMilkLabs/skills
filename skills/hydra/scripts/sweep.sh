#!/bin/zsh
# sweep.sh — delete hydra run dirs older than 7 days
find "$HOME/.claude/hydra-runs" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
echo "swept"
