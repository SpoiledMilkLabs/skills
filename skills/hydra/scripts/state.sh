#!/bin/zsh
# state.sh <window_id> — print head state: dead | trust-dialog | booting | working | awaiting-approval | idle-repl
WID=$1
C=$(osascript - "$WID" <<'EOF'
on run argv
	tell application "Terminal"
		repeat with w in windows
			if (id of w) = ((item 1 of argv) as integer) then
				return contents of selected tab of w
			end if
		end repeat
		return "__GONE__"
	end tell
end run
EOF
)
if [[ "$C" == "__GONE__" ]]; then echo dead; exit 0; fi
if echo "$C" | grep -q "Do you trust the files"; then echo trust-dialog; exit 0; fi
# spinner variants: "(esc to interrupt)", "✢ Pondering… (21m 36s · ↓ 89.1k tokens)", token counters
if echo "$C" | grep -qE "esc to interrupt|Compacting conversation|↓ [0-9.]+k tokens|[✻✢✽✳] [A-Z][a-z]+…"; then echo working; exit 0; fi
if echo "$C" | grep -qE "Do you want to|don't ask again"; then echo awaiting-approval; exit 0; fi
if echo "$C" | grep -q "❯"; then echo idle-repl; exit 0; fi
echo booting
