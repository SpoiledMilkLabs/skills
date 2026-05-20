# Changelog

All notable changes to skills in this repo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [semver](https://semver.org/).

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
