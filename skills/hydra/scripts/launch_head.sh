#!/bin/zsh
# launch_head.sh <run_dir> <n> <slug> <cwd> [model|default] [bypass|safe]
# Opens a Terminal window running bare `claude` (NO positional prompt — race-free protocol),
# color-codes it, titles it, records it in the run manifest. Prints the window id.
set -euo pipefail
RUN_DIR=$1; N=$2; SLUG=$3; CWD=$4; MODEL=${5:-default}; BYPASS=${6:-bypass}
mkdir -p "$RUN_DIR/status" "$RUN_DIR/kickoff"

CMD="cd $(printf '%q' "$CWD") && claude"
[[ "$MODEL" != "default" ]] && CMD="$CMD --model $MODEL"
[[ "$BYPASS" == "bypass" ]] && CMD="$CMD --dangerously-skip-permissions"

PROFILES=("Basic" "Ocean" "Grass" "Red Sands" "Silver Aerogel" "Homebrew" "Novel" "Pro")
PROF=${PROFILES[$(( (N-1) % 8 + 1 ))]}

WID=$(osascript - "$CMD" "H$N $SLUG" "$PROF" <<'EOF'
on run argv
	tell application "Terminal"
		activate
		do script (item 1 of argv)
		delay 0.8
		set w to front window
		try
			set current settings of selected tab of w to settings set (item 3 of argv)
		end try
		try
			set font size of selected tab of w to 11
		end try
		set custom title of selected tab of w to (item 2 of argv)
		return id of w
	end tell
end run
EOF
)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$N" "$SLUG" "$WID" "$CWD" "$MODEL" "$BYPASS" >> "$RUN_DIR/manifest.tsv"
echo "$WID"
