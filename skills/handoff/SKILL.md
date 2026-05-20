---
name: handoff
version: 1.1.0
description: Capture session state at end of a coding session so a future Claude Code session can resume cold, or resume from a prior handoff. Trigger PROACTIVELY when the user signals end of session — "wrapping up", "call it for tonight", "let's stop here", "I need to go", "continue tomorrow", "pick this up later", "save where we are", "done for now" — and also on explicit /handoff. For resume, trigger when user says "resume", "pick up where we left off", "continue from yesterday", "what was I working on", or /handoff resume.
risk: low
source: composite (willseltzer create template + hacktivist123 resume protocol + multi-project index)
repo: https://github.com/SpoiledMilkLabs/skills
---

# Handoff

Capture session state for cold-start resume. Three modes: **create** (default), **resume**, **list**.

## Configuration

The skill reads `~/.claude/handoffs/config.json` on every invocation. If the file doesn't exist, use these defaults and write the file on first run so the user can edit it:

```json
{
  "retention": "archive",
  "max_versions": 10,
  "history_path": "sessions/.history/",
  "auto_obsidian_log": true,
  "update_check": {
    "enabled": true,
    "repo": "SpoiledMilkLabs/skills"
  }
}
```

- `retention`: `"archive"` (default) keeps a single archived copy of an orphaned handoff. `"version-history"` keeps the last `max_versions` of each handoff under `history_path`. See **Retention modes** below.
- `max_versions`: cap for `version-history` mode. Older versions get pruned.
- `history_path`: relative to `~/.claude/handoffs/`. Folder structure: `<history_path>/<slug>/vN.md`.
- `auto_obsidian_log`: append archive events to `~/knowledge/wiki/log.md` if the vault exists. Off = silent archival.
- `update_check.enabled`: see **Update check** at the bottom.

If the JSON is malformed, fall back to defaults and tell the user to fix the file — don't silently proceed.

## Core invariant — one handoff per project key

A **project key** is:
- For a git repo: the absolute path of the git root (e.g. `/Users/melqui/base44-migration`)
- For a non-repo session: a stable kebab-case slug (e.g. `linkedin-profile-ai-pivot`) — NOT timestamped

Every project key maps to **exactly one** handoff file and **exactly one** line in the index. New handoffs overwrite — they do not accumulate. Historical state lives in git for repos; for non-repos, the file is overwritten and the previous version is gone (move to archive only if it's being orphaned by a different slug taking its spot — see "Archival" below).

## When to use

**Create** — proactively when the user signals end-of-session (see trigger phrases in description) OR on explicit `/handoff`. Confirm in one line before writing: "Writing handoff to `<path>` — proceed?"

**Resume** — when user asks to pick up prior work, OR proactively at start of a fresh session if a HANDOFF.md exists in the current project and is < 14 days old. Surface with: "Found handoff from <date> — want me to resume from it?"

**List** — when user asks "what was I working on", "what's hot", "show me my open sessions". Read `~/.claude/handoffs/index.md` and show the top entries (newest first).

## Create mode

### Step 1 — Determine the project key and target path

```bash
git rev-parse --show-toplevel 2>/dev/null  # if set, this is the project key (git mode)
git branch --show-current 2>/dev/null
git log -1 --format='%h %s' 2>/dev/null
git status --short 2>/dev/null
```

- **Git mode** (in a repo): target = `<project-root>/HANDOFF.md`, key = `<project-root>`.
- **Non-git mode**: target = `~/.claude/handoffs/sessions/<slug>.md`, key = `<slug>`.
  - If you resumed an existing session earlier in this conversation, **reuse that exact slug** — never invent a new one.
  - For a brand-new non-git session, propose a slug (3-5 word kebab) and ask: "Use slug `<slug>`, or continue an existing session?" If `<slug>.md` already exists in `sessions/`, also ask before overwriting.

### Step 2 — Write the handoff using this template

```markdown
# Handoff — YYYY-MM-DD HH:MM

**Project:** <absolute path or repo name>
**Branch:** <branch name, or "n/a (not a repo)">
**HEAD:** <short SHA + subject>
**Working tree:** <"clean" or "N modified, M untracked" with brief list>

## Goal
<1-2 sentences: what we set out to do this session and why>

## Status

### DONE
- <concrete deliverable, with file:line refs where useful>

### PARTIAL
- <work started; what specifically remains; which file/function is half-done>

### NOT DONE
- <items from the goal we didn't get to>

## Next step
<The single most-actionable thing to do first when resuming. One sentence. Include the file path or command to start with.>

## Files to know
| Path | Why it matters |
|------|----------------|
| path/to/file.ts | What this file's role is and what we changed/explored |

## Key decisions
| Decision | Rationale |
|----------|-----------|
| Chose X over Y | Because Z |

## Failed approaches (don't retry without new info)
- <Approach tried + why it failed. Saves the next session from re-attempting.>

## Open questions / blockers
- <Unresolved questions, missing credentials, waiting on someone, etc.>

## References
- <PRs, issues, commits, docs, Slack threads — link, don't paraphrase>
```

### Step 3 — Upsert the index (NOT append)

Read `~/.claude/handoffs/index.md`. Drop any existing line whose project key matches the one you're writing. Prepend the new line at the top (newest first). Create the file with a header if it doesn't exist:

```markdown
# Handoff Index

One line per project key. Newest on top. Lines are replaced in place when the same project gets a new handoff — never appended blindly.

Format: `- YYYY-MM-DD HH:MM · <project-path-or-session-file> · <branch> · Next: <one-liner>`

```

The matching rule: a line matches if its second `·`-separated field (project-path or session-file path) equals the new entry's. Be exact — don't fuzzy-match.

### Step 4 — Confirm

Tell the user: "Handoff written to `<path>` and indexed. Next session can resume with `/handoff resume`."

## Resume mode

### Step 1 — Locate the handoff

- If a `HANDOFF.md` exists in the current directory's git root, use it.
- Otherwise read `~/.claude/handoffs/index.md` and show the top 5 entries (it's already deduped, so 5 = 5 distinct projects). Ask which one to resume.

### Step 2 — Remember the source path for this conversation

**Critical for the overwrite contract.** Once you've located the handoff file, treat its path as the "active handoff path" for the rest of this conversation. When a subsequent `create` invocation happens in the same session, **silently overwrite that exact file** — do not generate a new slug, do not ask, do not add a new index line. The index line for that project key gets updated in place per Create Step 3.

### Step 3 — Read it fully

Read the entire HANDOFF.md. Do not skim. The Failed Approaches and Key Decisions sections are load-bearing — skipping them means re-litigating settled questions.

### Step 4 — Validate against workspace (workspace is ground truth)

```bash
git status --short
git log -5 --format='%h %ad %s' --date=short
git diff <handoff-HEAD>..HEAD --stat 2>/dev/null  # what changed since the handoff
```

For each item in DONE: spot-check the file actually contains the claimed change. If a DONE item's file has since been modified or reverted, **re-classify it as PARTIAL or NOT DONE** and tell the user.

For each item in PARTIAL: verify the half-done state still exists. If it's been finished or abandoned in commits since, update the status.

**Never trust the handoff over the workspace.** A handoff is a frozen snapshot; the repo is current truth.

### Step 5 — Re-state and proceed

Summarize in 3-5 lines:
- Where we left off (the Next step from the handoff)
- What's changed since (commits, working-tree state)
- Any DONE→PARTIAL reclassifications
- The single action you're about to take

Then start from "Next step" — don't re-plan from scratch unless the workspace has drifted enough to invalidate it.

## List mode

Read `~/.claude/handoffs/index.md` and show the top entries (newest first — `head`, not `tail`, since the index is now deduped and sorted newest-first). Present as a small table: date · project · next step. Help them pick.

## Retention modes

Branch on `config.retention` before writing a handoff that would replace an existing one.

### Mode A — `archive` (default)

Same-slug overwrites just overwrite. No version is kept.

Only when an old slug is being *displaced* (dropped from the index because a different project takes its slot, or a non-repo session became a git repo), do this BEFORE writing the new entry:

1. `mkdir -p ~/.claude/handoffs/sessions/archive/`
2. Move the orphaned `sessions/<slug>.md` into `sessions/archive/<slug>.md` (overwrite-safe — re-archiving the same slug is fine).
3. If `config.auto_obsidian_log` is true AND `~/knowledge/wiki/log.md` exists, append:

   ```
   ## YYYY-MM-DD — Handoff archived: <slug>
   - **File:** `~/.claude/handoffs/sessions/archive/<slug>.md`
   - **Type:** handoff-archive
   - **Last next-step:** <one-liner from the dropped index line>
   - **Reason:** <"superseded by <new-slug>" or "project moved into git repo at <path>" or "manual archive">
   ```

   If the vault doesn't exist, skip silently — don't error.

4. Git-repo `HANDOFF.md` files are *never* archived — they're overwritten in place and git history holds the past.

### Mode B — `version-history`

Every overwrite is preserved as a numbered version.

For non-repo handoffs:

1. Before writing, if `sessions/<slug>.md` exists, find the highest `vN.md` under `<history_path>/<slug>/` (start at v1 if folder is empty).
2. Move the current `sessions/<slug>.md` to `<history_path>/<slug>/v<N+1>.md`.
3. Write the new handoff to `sessions/<slug>.md`.
4. Prune `<history_path>/<slug>/v*.md` files to the most recent `config.max_versions`. Delete the oldest ones.

For git-repo handoffs in `version-history` mode:

1. Before overwriting `<project-root>/HANDOFF.md`, copy it to `<project-root>/.handoff-history/v<N+1>.md` (create the dir + add to repo's `.gitignore` automatically if not already there — these are local-only, not committed).
2. Prune as above.
3. Then overwrite `HANDOFF.md`.

When listing in resume mode, mention prior versions: `"Resuming linkedin-profile-ai-pivot.md (retention: version-history, 3 prior versions kept)"`.

If `config.retention` is anything other than `"archive"` or `"version-history"`, log a warning and fall back to `archive`.

## Rules

- **One handoff per project key, overwritten each time.** No timestamped filenames in `sessions/`. No multiple lines per project in the index.
- **The index is upserted, not appended.** Same project key → replace the existing line. New project key → prepend. Sort newest-first.
- **Resume → Create silently overwrites the resumed file** within the same conversation. No new file, no confirmation prompt.
- **Be concrete in Next step.** "Continue the migration" is useless. "Run `npm run migrate:dev` then edit `prisma/schema.prisma` line 47" is useful.
- **Don't duplicate PRDs/specs/ADRs.** Reference them by path. The handoff is a pointer, not a copy.
- **Capture failure, not just success.** The Failed Approaches section is the highest-value part — it's the thing only the live session knows that a fresh session can't recover from the repo.
- **If working tree is dirty, say so explicitly.** A future session resuming with uncommitted changes needs to know whether to commit, stash, or continue editing.

## Update check

When **resume mode** or **list mode** is invoked (not on every create — too noisy), check whether a newer release exists:

1. Skip the check entirely if `config.update_check.enabled` is false.
2. Read `~/.claude/skills/handoff/.update-check.json` if it exists. If its `date` field equals today's date (YYYY-MM-DD), skip — already checked today.
3. Otherwise, fetch the latest release tag from `config.update_check.repo`:
   ```bash
   curl -s -m 5 "https://api.github.com/repos/$REPO/releases/latest" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))"
   ```
   Be tolerant: if the request times out, returns no JSON, or you have no network, just skip — never block resume on this.
4. Compare to the local `version:` from this file's frontmatter. If the remote is strictly newer (semver compare), print ONE line at the top of the resume/list output:

   ```
   ℹ Handoff skill v<remote> available (you have v<local>). Update with: cd <clone> && git pull && ./install.sh
   ```

5. Write `~/.claude/skills/handoff/.update-check.json` with `{"date": "YYYY-MM-DD", "latest_tag": "<tag>"}` so we throttle to once per day.

Never auto-pull — surfacing the notice is enough.

## Anti-patterns

- ❌ Writing a handoff with vague Next step ("keep going on the feature").
- ❌ Generating a timestamped slug (`2026-05-20-1700-foo.md`) for a non-repo session — slugs are stable, not dated.
- ❌ Appending a new index line for a project that already has one. Replace, don't accumulate.
- ❌ After resume, writing the next handoff to a *new* path. Reuse the resumed path.
- ❌ Overwriting HANDOFF.md without reading the existing one first — you may lose Failed Approaches the user paid in time to learn.
- ❌ Marking something DONE in resume mode without checking the file.
- ❌ Creating handoffs after trivial sessions (a single typo fix, a one-line commit). Save handoffs for sessions with real in-flight state.
