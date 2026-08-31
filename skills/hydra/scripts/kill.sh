#!/bin/zsh
# kill.sh <run_dir> [n] — kill one head (or all) by tty, then close its now-idle window.
set -euo pipefail
RUN_DIR=$1; ONLY=${2:-}
while IFS=$'\t' read -r n slug wid cwd model bypass; do
	[[ -z "$n" ]] && continue
	[[ -n "$ONLY" && "$n" != "$ONLY" ]] && continue
	TTY=$(osascript - "$wid" <<'EOF'
on run argv
	tell application "Terminal"
		repeat with w in windows
			if (id of w) = ((item 1 of argv) as integer) then return tty of selected tab of w
		end repeat
		return ""
	end tell
end run
EOF
)
	if [[ -n "$TTY" ]]; then
		pkill -9 -t "${TTY#/dev/}" 2>/dev/null || true
		sleep 1
		osascript - "$wid" <<'EOF' >/dev/null 2>&1 || true
on run argv
	tell application "Terminal"
		repeat with w in windows
			if (id of w) = ((item 1 of argv) as integer) then close w
		end repeat
	end tell
end run
EOF
		echo "head $n: killed ($TTY)"
	else
		echo "head $n: window already gone"
	fi
done < "$RUN_DIR/manifest.tsv"
