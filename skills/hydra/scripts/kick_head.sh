#!/bin/zsh
# kick_head.sh <run_dir> <n>
# Drives one head to "working": answers the trust dialog (down+enter), waits out boot,
# submits the kickoff prompt from <run_dir>/kickoff/<n>.txt (MUST be a single line), verifies.
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
RUN_DIR=$1; N=$2
WID=$(awk -F'\t' -v n="$N" '$1==n{print $3}' "$RUN_DIR/manifest.tsv" | tail -1)
[[ -z "$WID" ]] && { echo "head $N not in manifest"; exit 1; }
KICK=$(head -1 "$RUN_DIR/kickoff/$N.txt")
KICKED=0
S=unknown
for i in {1..45}; do
	S=$("$DIR/state.sh" "$WID")
	case "$S" in
		dead) echo "head $N: DEAD"; exit 1 ;;
		trust-dialog)
			# Yes = down-arrow + enter; do script's trailing newline is the enter
			osascript - "$WID" <<'EOF'
on run argv
	tell application "Terminal"
		repeat with w in windows
			if (id of w) = ((item 1 of argv) as integer) then
				do script ((character id 27) & "[B") in selected tab of w
			end if
		end repeat
	end tell
end run
EOF
			sleep 2 ;;
		booting) sleep 2 ;;
		idle-repl)
			if [[ $KICKED -eq 1 ]]; then
				sleep 2
			else
				osascript - "$WID" "$KICK" <<'EOF'
on run argv
	tell application "Terminal"
		repeat with w in windows
			if (id of w) = ((item 1 of argv) as integer) then
				do script (item 2 of argv) in selected tab of w
			end if
		end repeat
	end tell
end run
EOF
				KICKED=1
				sleep 3
			fi ;;
		working) echo "head $N: working"; exit 0 ;;
		awaiting-approval) echo "head $N: awaiting-approval (needs human)"; exit 0 ;;
	esac
	sleep 2
done
echo "head $N: TIMEOUT (last state: $S, kicked: $KICKED)"; exit 1
