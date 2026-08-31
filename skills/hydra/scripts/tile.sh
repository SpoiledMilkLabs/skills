#!/bin/zsh
# tile.sh <run_dir> [--reserve <conductor_window_id>]
# Tiles all manifest windows in a ceil(sqrt(N)) grid. With --reserve, the conductor
# window gets the last cell so it stays visible alongside the heads.
set -euo pipefail
RUN_DIR=$1; shift || true
RESERVE=""
if [[ "${1:-}" == "--reserve" ]]; then RESERVE=$2; fi
WIDS=($(awk -F'\t' '{print $3}' "$RUN_DIR/manifest.tsv"))
[[ -n "$RESERVE" ]] && WIDS+=("$RESERVE")
osascript - "${WIDS[@]}" <<'EOF'
on run argv
	tell application "Finder" to set db to bounds of window of desktop
	set screenW to item 3 of db
	set screenH to item 4 of db
	set topOffset to 25
	set n to count of argv
	set cols to (round ((n ^ 0.5)) rounding up)
	set rowsN to (round ((n / cols)) rounding up)
	set cellW to screenW div cols
	set cellH to (screenH - topOffset) div rowsN
	tell application "Terminal"
		repeat with i from 1 to n
			set wid to ((item i of argv) as integer)
			set x1 to ((i - 1) mod cols) * cellW
			set y1 to topOffset + (((i - 1) div cols) * cellH)
			repeat with w in windows
				if (id of w) = wid then set bounds of w to {x1, y1, x1 + cellW, y1 + cellH}
			end repeat
		end repeat
	end tell
end run
EOF
echo "tiled ${#WIDS[@]} windows"
