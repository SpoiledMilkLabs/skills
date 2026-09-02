---
name: hydra
version: 1.0.3
description: Fan multiple independent tasks out to SEPARATE Terminal.app windows, each running its own live claude session with exactly the context it needs — real parallel sessions with isolated context windows, not subagents. Confirms grouping/model/risk with the user before launching, delivers context invisibly, auto-tiles windows, and signals completion via done-files + macOS toasts. Trigger when the user types /hydra <tasks | transcript>, /hydra status|rekick|kill|clean, or asks to split work across terminals / open a terminal per task / "one claude per task". NOT for subagent parallelism inside one session, and not for single tasks.
risk: high
source: original
repo: https://github.com/SpoiledMilkLabs/skills
---

# Hydra — one head becomes many

Turn a pile of tasks (a list, a meeting transcript, a brain dump) into N isolated Terminal.app claude sessions — grouped, confirmed, launched via tested scripts, kicked off, tiled, and signal-driven.

**Hydra vs subagents:** subagents run inside the parent session (shared budget, results come back there). Hydra heads are real independent `claude` sessions with their own full context windows, watchable and steerable by the user. A task earns a head only if it is long-running AND lives in a distinct repo/context AND benefits from being watchable. Otherwise use a subagent or do it sequentially. Real-world calibration: typical heads finish in 5–25 minutes, not hours.

**Platform:** macOS + Terminal.app. **All mechanics live in tested scripts** at `~/.claude/skills/hydra/scripts/` — call them, never re-derive AppleScript inline. Scripts that touch osascript need sandbox disabled for the Bash call.

## Subcommands

- `/hydra <tasks|transcript>` → full launch flow below.
- `/hydra status` → `scripts/status.sh <run_dir>` on the newest dir in `~/.claude/hydra-runs/`; present the table plus one-line "last screen output" per non-done head.
- `/hydra rekick <n>` → `scripts/rekick.sh <run_dir> <n>` (revives a dead head with `claude --continue` in its cwd).
- `/hydra kill [n]` → `scripts/kill.sh <run_dir> [n]` (kills by tty, closes windows). Confirm with the user first.
- `/hydra clean` → after confirming the run is finished, delete its run dir; `scripts/sweep.sh` also auto-purges runs older than 7 days.

## Phase 0 — Hygiene
Run `scripts/sweep.sh`. Capture the conductor's own window id now (front Terminal window before launching anything) for the tiling reserve.

## Phase 1 — Group, decide, CONFIRM

1. Parse into discrete tasks; group by **where the work happens** (repo/system/API). One terminal = one working directory = one owner. Two groups needing the same repo → separate worktrees off `origin/main`.
2. Verify every working dir exists (`ls`) — never guess.
3. Wire cross-group dependencies as **handoff files** (absolute path + consumer fallback), and plan **waves**: producers launch in wave 1; a consumer whose input is hard-required launches when the handoff file exists (conductor polls between waves).
4. **Model strategy.** Propose one of the named strategies (model aliases only — e.g. fable/opus/sonnet/haiku — never pinned IDs):
   - **maestro** (default): the conductor (this session, on the flagship model) does all planning and doc-writing; heads get execution tiers by task nature — `sonnet` for well-specified builder work, `haiku` for purely mechanical/read-heavy work, flagship/default only for a head with genuine ambiguity or architecture decisions.
   - **flagship-lead:** the hardest/most ambiguous head gets the flagship model, every other head a mid tier.
   - **uniform:<model>** — every head the same model.
   - **custom** — the user dictates per-head models.
   Fill the per-head model column from the chosen strategy; weight the burn estimate by model cost.
5. Decide per head: **risk tier** (🟢 local-only / 🟡 deploys / 🔴 money paths or prod data — offer `safe` mode, i.e. no bypass flag, for 🔴 heads).
6. **Confirmation gate (mandatory):** present a table — head #, working dir, tasks, model, risk, wave, dependencies — plus estimated usage burn (each head ≈ a full session's turn; warn above 4 heads and suggest merges). Then ask the user two questions: (a) *Launch with this grouping?* — launch as-is / adjust; (b) *Model strategy?* Apply the answers before launching. Skip the gate only if the user explicitly pre-approved ("just launch" — then use maestro).

## Phase 2 — Package context (invisible by default)

Run dir: `~/.claude/hydra-runs/<YYYYMMDD-HHMM>/`. Per head write `kickoff/<n>.txt` — ONE single line (no literal newlines; `do script` submits on newline):

- **Small task** (~≤800 chars total): the kickoff line carries everything — task, cwd, constraints, definition of done. No doc.
- **Normal case:** write a self-contained doc at `<run_dir>/docs/<n>-<slug>.md`; kickoff line = `Read the task file '<abs path>' and execute it fully. Follow every constraint and the definition of done in it. Work autonomously to completion.` Docs live in the run dir, not on the Desktop (unless the user asks for drag-droppable files) and never in a temp dir that a reboot wipes mid-run.

Each doc must include: one-paragraph context; verified working dir; numbered tasks needing zero clarification; ONLY the standing rules and known footguns relevant to that repo (env-file handling, deploy conventions, public-repo hygiene, verification requirements…); handoff files produced/consumed with fallbacks; a definition of done with real verification (render/screenshot/reconcile-to-zero) plus "report what's blocked and on whom"; and the **completion signal block**:

```
When fully done, as your final actions:
1. echo "<one-line outcome summary>" > <run_dir>/status/<n>.done
2. osascript -e 'display notification "H<n> <slug> finished" with title "Hydra"'
3. If ListAgents shows another local Claude session (the conductor), SendMessage it a 3-line completion report.
```

**Doc lifetime:** never delete docs while heads run (context compaction re-reads them). `/hydra clean` or the 7-day sweep handles them after.

## Phase 3 — Launch (wave 1)

Per head: `scripts/launch_head.sh <run_dir> <n> <slug> <cwd> <model|default> <bypass|safe>` → opens a window running **bare `claude` with NO positional prompt** (this sidesteps the trust-dialog/prompt race entirely), applies a distinct color profile + font size 11 + tab title `H<n> <slug>`, appends to `manifest.tsv`, prints the window id.

Then tile: `scripts/tile.sh <run_dir> --reserve <conductor_window_id>` — grid of ceil(sqrt(N+1)), conductor keeps the last cell.

## Phase 4 — Kick

Per head: `scripts/kick_head.sh <run_dir> <n>` — polls state every 2s (45 tries): answers the folder-trust dialog (down-arrow+Enter via tty injection), waits out `booting` (NEVER type into a window before the REPL chrome is visible — text typed into a bare shell would EXECUTE as shell commands), submits the kickoff once at `idle-repl`, exits on `working`. If it reports timeout, read the window manually and intervene.

Launch wave 2+ heads (Phase 3+4 again) when their handoff files appear.

## Phase 5 — Report & monitor

Report: table (head → window id → repo → model/risk → summary), watch-list (shared repos, handoff files, anything that deploys — cross-session deploys serialize manually), run dir path. Completion arrives by itself: macOS toast + done-file per head (and possibly a SendMessage into the conductor chat). Offer — don't auto-start — a recurring status check. `awaiting-approval` state = a safe-mode head needs a human at its window.

## Known gotchas (hard-won — trust these over intuition)

- The folder-trust dialog does **NOT** eat the CLI positional prompt — accepting trust releases it (with a delay). Checking too early reads as "idle, prompt lost", and a re-typed kickoff lands as duplicate unsubmitted text while the head works. The bare-claude protocol makes this moot; if a stray unsubmitted kickoff ever sits in an idle head's input box, clear it: `do script (character id 27) in selected tab` (ESC clears input; the trailing newline is a harmless empty submit). Only on idle heads — ESC interrupts a working one.
- Working-spinner text varies: "esc to interrupt" is often absent; also match `↓ N.Nk tokens` and `✻/✢/✽/✳ Verb…` lines (state.sh does).
- `frontmost` is not a Terminal window property (use `set index of w to 1`), and AppleScript `try` blocks swallow that error silently.
- `contents of selected tab` = visible screen only; scrollback is `history`.
- System Events keystrokes require Accessibility permission for your terminal app; the tty-injection path (`do script … in selected tab`) needs nothing — prefer it.
- Capture `id of front window` immediately after each launch; matching windows by screen contents later is fragile (the TUI clears the screen).
