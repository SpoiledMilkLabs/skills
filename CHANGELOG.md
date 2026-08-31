# Changelog

All notable changes to skills in this repo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [semver](https://semver.org/).

## [1.4.1] — 2026-09-01

### Hydra skill (v1.0.1)

#### Fixed

- **REPL submit bug**: `do script "text"` only inserts into the Claude Code input box — the trailing newline never submits (paste handling swallows it). `kick_head.sh` now follows the kickoff with a bare `do script ""`, which acts as the Enter press. Dialogs still react to the plain trailing newline; only the REPL input box needs the extra step.
- **Spinner detection**: multibyte spinner glyphs moved from a grep bracket class (which matches bytes, not characters) to alternation, and token counters without a `k` suffix (`↓ 88 tokens`) now count as working.

## [1.4.0] — 2026-08-31

### Hydra skill (new, v1.0.0)

#### Added

- **Hydra**: fan multiple independent tasks out to separate Terminal.app windows, each a live `claude` session with exactly the context it needs. Born from running six real tasks in parallel and keeping every gotcha the run surfaced.
- Tasks grouped by working directory (one terminal = one repo = one owner; shared repos get worktrees), with cross-task handoff files and staged launch waves for dependencies.
- **Confirmation gate before spending anything**: grouping table, per-head risk tier (with a no-bypass "safe" mode for heads that touch money paths or prod), usage-burn warning above 4 heads, and a **model strategy** pick — maestro (flagship plans, sonnet/haiku execute), flagship-lead, uniform, or custom.
- Mechanics shipped as eight tested shell scripts (launch, kick, state, status, tile, kill, rekick, sweep) driven by a per-run TSV manifest — nothing re-derived at runtime.
- Race-free launch protocol: bare `claude` with no positional prompt, kick only when the REPL is provably ready. Auto-answers the folder-trust dialog via tty injection (no Accessibility permission needed).
- Windows auto-tile into a grid with a cell reserved for the conductor, color-coded profiles, and per-head tab titles.
- Push-based completion: each head writes a done-file and fires a macOS notification when finished.
- A "Known gotchas" section documenting the failure modes that cost real debugging time (trust dialog vs positional prompt, spinner-text variants, `frontmost` not being a window property, screen-contents vs scrollback).



### Handoff skill

#### Added

- **Digest / Appendix template split.** The handoff template is now two parts: a tight Digest (Goal, Status totals, Next step) at the top and an Appendix (DONE/PARTIAL/NOT DONE lists, Files to know, Key decisions, Failed approaches, Open questions, References) below. Resume mode reads the whole file but only *re-states* the Digest into working memory — the Appendix is consulted on demand when the next action touches it. Burns roughly 70% fewer tokens per resume.
  - *Backward compatible:* old handoffs without the split are treated as one big Digest.
- **Ambiguous-cwd guard for `.active.json`.** When cwd is exactly `$HOME` or `/`, the pin is too coarse to silently trust — the skill now surfaces a one-line confirm ("Reuse pinned slug `<slug>` from <date>, or start a new session?") before reusing. Without this, unrelated sessions started from `$HOME` would silently overwrite each other's handoffs.
- **Secrets discipline.** New rule + anti-pattern: never inline API keys, tokens, `.env` values, passwords, or PII into a handoff. Reference by path; never by value. Handoffs sit in `~/.claude/handoffs/` and are read by any future model invocation.
- **"What this skill does NOT do" section.** Explicitly states the skill cannot relieve in-session context — the conversation transcript is already cached when `/handoff create` runs. Step 5 now prompts the user to `/clear` before resuming, with a callout that a fresh session resumes for ~500 tokens vs the full transcript.
- **`update_check.throttle_days` config.** Default 7 (was effectively daily). Tuning knob for users who want quieter checks.

#### Changed

- **Update check moved off resume.** Resume mode no longer blocks on the GitHub API call — that 3–5 second roundtrip on the first invocation of the day made resume feel slow. The check now fires on `list` mode only (a less-frequent, user-initiated discovery flow). Timeout tightened from 5s to 3s.
- **Resume Step 4 skips the diff when HEAD hasn't moved.** Parses the handoff's `**HEAD:**` line, compares to current `HEAD`. Equal SHAs → skip `git diff <handoff-HEAD>..HEAD`. Falls back gracefully if the SHA was force-pushed away.
- **`Files to know` and `Key decisions` switched from markdown tables to bullet lists.** Tables cost roughly 30% more tokens to read than equivalent bullets, and the resume path reads these on most invocations.
- **Step 5 confirm message rewritten** with explicit instructions on the `/clear` step.

[1.3.0]: https://github.com/SpoiledMilkLabs/skills/releases/tag/v1.3.0

## [1.2.0] — 2026-05-21

### Handoff skill

#### Added

- **`.active.json` slug pin for post-`/clear` recovery.** Non-git handoffs now write `~/.claude/handoffs/.active.json` mapping the absolute cwd to the active slug. When `/clear` wipes in-conversation memory, the next invocation in the same cwd silently reuses the pinned slug instead of inventing a fresh one and orphaning the existing handoff file. TTL: 7 days. Atomic write via `.tmp` + `mv`.
  - *Before:* `/clear` + `/handoff` in the same cwd generated a new slug, displaced the old line from the index, and (under `retention: archive`) moved the old file into `sessions/archive/` — effectively deleting saved state.
  - *After:* same flow silently reuses the pinned slug. No archive sweep, no displacement.
- **Resume mode also writes the pin.** When resuming a non-git handoff, the slug is pinned to disk for the current cwd — so a `/clear` mid-resume still survives.

[1.2.0]: https://github.com/SpoiledMilkLabs/skills/releases/tag/v1.2.0

## [1.1.1] — 2026-05-20

### Changed
- **`install.sh` now prints the version of each skill it installs.** Reads the `version:` field from each `SKILL.md` and appends it in parentheses (e.g. `installed handoff (1.1.0)`). Empty version field is tolerated — line falls back to skill name only.

[1.1.1]: https://github.com/SpoiledMilkLabs/skills/releases/tag/v1.1.1

## [1.1.0] — 2026-05-20

### Handoff skill

#### Added

- **Per-project key dedup in the index.** `~/.claude/handoffs/index.md` now holds one line per project key — the git root for repos, or a stable slug for non-repo sessions. New handoffs replace the matching line in place. Sorted newest-first.
  - *Before:* every session appended a fresh line. After seven sessions across three projects, the index had seven lines. Resume mode showed all seven.
  - *After:* same projects collapse to a single line each. Resume mode shows distinct projects only. The skill upserts by key on every write.
  - *How to use:* nothing to do. The behavior change is automatic the next time you trigger create or resume.
- **Resume → Create silent overwrite.** When the next handoff is written in the same conversation that resumed an earlier one, it overwrites the resumed file silently. No new file, no new index line.
  - *Before:* every create generated a new timestamped slug, even if it was a direct continuation.
  - *After:* the resumed path is remembered for the conversation, and the next create reuses it.
  - *How to use:* same as before — just say "let's wrap up" or "/handoff" at the end of a session you resumed.
- **`~/.claude/handoffs/config.json`.** User-configurable retention behavior with two modes:
  - `archive` (default): orphaned non-repo handoffs move to `sessions/archive/<slug>.md`. Single archive slot per slug. Matches old behavior.
  - `version-history`: every overwrite gets preserved at `sessions/.history/<slug>/vN.md`. Last `max_versions` kept (default 10), older versions pruned. For git-repo handoffs, copies also land at `<project-root>/.handoff-history/vN.md` before overwrite.
  - *How to use:* edit the JSON if you want `version-history`. The file is written on first run with archive defaults so nothing surprises anyone after upgrade.
- **Archive sweep with Obsidian log integration.** When a non-repo session gets displaced and `config.auto_obsidian_log` is true, the archive event appends a block to `~/knowledge/wiki/log.md`. Silently no-ops if the vault doesn't exist.
- **Update check.** Resume and list modes now hit `api.github.com/repos/<repo>/releases/latest` once per day and surface a one-liner if a newer release exists. Throttled via `~/.claude/skills/handoff/.update-check.json`. Never auto-pulls — the user runs `git pull && ./install.sh` themselves.

#### Changed

- **Non-repo session filenames lost their date prefix.** Old: `2026-05-17-0239-linkedin-profile-ai-pivot.md`. New: `linkedin-profile-ai-pivot.md`. Stable across sessions, so same topic overwrites same file.
- **Index sort flipped to newest-first.** Use `head` (not `tail`) to see what's hot. The format string in the index header reflects this.
- **Resume mode now remembers the source path for the conversation.** Step 2 of resume mode (new in v1.1.0) is the contract that powers the silent overwrite above.

#### Removed

- The "index is append-only" rule. Replaced by per-project upsert.
- The date prefix on non-repo session filenames.
- The single-mode "Archival" section in SKILL.md. Replaced by "Retention modes" with the two-mode branch.

## [1.0.0] — 2026-05-16

### Added

- **Handoff skill.** Capture session state for cold-start resume. Three modes: create / resume / list. Per-project `HANDOFF.md` for git repos, timestamped session files for non-repos. Central index at `~/.claude/handoffs/index.md`. Workspace-as-truth validation on resume (DONE items spot-checked against the actual files).
- **Repo scaffold.** README, LICENSE (MIT), `install.sh`, `.gitignore`, `CONTRIBUTING.md`, `example-handoff.md`.

[1.1.0]: https://github.com/SpoiledMilkLabs/skills/releases/tag/v1.1.0
[1.0.0]: https://github.com/SpoiledMilkLabs/skills/releases/tag/v1.0.0
