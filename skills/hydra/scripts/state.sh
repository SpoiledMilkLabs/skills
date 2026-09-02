#!/bin/zsh
# state.sh <window_id> — print head state: dead | trust-dialog | shell | booting | working | awaiting-approval | idle-repl
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
# trust dialog wording varies by CC version; match all known variants BEFORE the ❯ check
if echo "$C" | grep -qE "Do you trust the files|Is this a project you created or one you trust|Yes, I trust this folder"; then echo trust-dialog; exit 0; fi
# a bare shell prompt below dead dialog scraps = claude exited
if echo "$C" | tail -3 | grep -qE "@Melquis-MacBook-Air .* %\s*$"; then echo shell; exit 0; fi
# spinner variants: "(esc to interrupt)", "✽ Propagating… (26s · ↓ 88 tokens · thinking)", "✢ Pondering… (21m 36s · ↓ 89.1k tokens)"
# NOTE: multibyte glyphs must be alternation (✻|✢), never a [bracket] class — grep matches bytes there
if echo "$C" | grep -qE "esc to interrupt|Compacting conversation|↓ [0-9.,]+k? tokens|(✻|✢|✽|✳|✶|✳️) [A-Z][a-z]+…|· thinking|will retry in|shell still running"; then echo working; exit 0; fi
if echo "$C" | grep -qE "Do you want to|don't ask again"; then echo awaiting-approval; exit 0; fi
if echo "$C" | grep -q "❯"; then echo idle-repl; exit 0; fi
echo booting
