#!/bin/zsh
# status.sh <run_dir> — table of every head: n, slug, window id, live state, done summary
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
RUN_DIR=$1
printf '%-3s %-22s %-7s %-18s %s\n' "N" "SLUG" "WIN" "STATE" "DONE"
while IFS=$'\t' read -r n slug wid cwd model bypass; do
	[[ -z "$n" ]] && continue
	if [[ -f "$RUN_DIR/status/$n.done" ]]; then
		st="done"
		summary=$(head -1 "$RUN_DIR/status/$n.done")
	else
		st=$("$DIR/state.sh" "$wid")
		summary=""
	fi
	printf '%-3s %-22s %-7s %-18s %s\n' "$n" "$slug" "$wid" "$st" "$summary"
done < "$RUN_DIR/manifest.tsv"
