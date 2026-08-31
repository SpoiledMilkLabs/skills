#!/bin/zsh
# rekick.sh <run_dir> <n> — revive a dead head: reopen a window in its cwd with
# `claude --continue` (resumes that repo's last session), update the manifest, re-kick.
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
RUN_DIR=$1; N=$2
ROW=$(awk -F'\t' -v n="$N" '$1==n{print}' "$RUN_DIR/manifest.tsv" | tail -1)
[[ -z "$ROW" ]] && { echo "head $N not in manifest"; exit 1; }
SLUG=$(echo "$ROW" | cut -f2); CWD=$(echo "$ROW" | cut -f4)
MODEL=$(echo "$ROW" | cut -f5); BYPASS=$(echo "$ROW" | cut -f6)

CMD="cd $(printf '%q' "$CWD") && claude --continue"
[[ "$MODEL" != "default" ]] && CMD="$CMD --model $MODEL"
[[ "$BYPASS" == "bypass" ]] && CMD="$CMD --dangerously-skip-permissions"

WID=$(osascript - "$CMD" "H$N $SLUG" <<'EOF'
on run argv
	tell application "Terminal"
		activate
		do script (item 1 of argv)
		delay 0.8
		set custom title of selected tab of front window to (item 2 of argv)
		return id of front window
	end tell
end run
EOF
)
# replace manifest row with new window id
TMP=$(mktemp)
awk -F'\t' -v OFS='\t' -v n="$N" -v w="$WID" '$1==n{$3=w} {print}' "$RUN_DIR/manifest.tsv" > "$TMP" && mv "$TMP" "$RUN_DIR/manifest.tsv"
echo "head $N: revived in window $WID (claude --continue). Prompt it to resume its task doc if it does not pick up automatically."
